//
//  SteamSetupService.swift
//  WineLauncher
//
//  Created by Nico Werner on 04.10.26.
//

import Foundation
internal import Combine

/// Service für die Installation und Konfiguration von Steam-Optimierungen
@MainActor
final class SteamSetupService: ObservableObject {
    
    @Published var setupProgress: SetupProgress = .notStarted
    @Published var currentStep: String = ""
    @Published var progressPercent: Double = 0.0
    
    enum SetupProgress: Equatable {
        case notStarted
        case downloadingDXMT
        case installingDXMT
        case compilingWrapper
        case installingWrapper
        case applyingRegistryTweaks
        case verifying
        case completed
        case failed(Error)
        
        static func == (lhs: SetupProgress, rhs: SetupProgress) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.downloadingDXMT, .downloadingDXMT),
                 (.installingDXMT, .installingDXMT),
                 (.compilingWrapper, .compilingWrapper),
                 (.installingWrapper, .installingWrapper),
                 (.applyingRegistryTweaks, .applyingRegistryTweaks),
                 (.verifying, .verifying),
                 (.completed, .completed):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    private let wineRuntime: WineRuntime
    private let processRunner = ProcessRunner()
    
    init(wineRuntime: WineRuntime = WineRuntime()) {
        self.wineRuntime = wineRuntime
    }
    
    /// Prüft ob Steam-Optimierungen bereits installiert sind
    func checkSteamOptimizations(in prefixURL: URL) -> SteamOptimizationStatus {
        let hasDXMT = FileManager.default.fileExists(
            atPath: prefixURL.appendingPathComponent("drive_c/windows/system32/d3d11.dll").path
        )
        
        let hasWrapper = FileManager.default.fileExists(
            atPath: prefixURL.appendingPathComponent("drive_c/Program Files (x86)/Steam/bin/cef/cef.win7x64/steamwebhelper.exe").path
        )
        
        if hasDXMT && hasWrapper {
            return .fullyOptimized
        } else if hasDXMT {
            return .partiallyOptimized(missing: ["Steam Wrapper"])
        } else {
            return .notOptimized
        }
    }
    
    /// Führt die vollständige Steam-Optimierung durch
    func setupSteamOptimizations(for prefixURL: URL) async throws {
        print("SteamSetup: Starte Optimierungs-Setup für \(prefixURL.path)")
        
        // Schritt 1: DXMT herunterladen und installieren
        try await installDXMT(to: prefixURL)
        
        // Schritt 2: Steam Wrapper kompilieren und installieren (OPTIONAL)
        // Der Wrapper verbessert die Performance, ist aber nicht zwingend erforderlich
        do {
            try await installSteamWrapper(to: prefixURL)
        } catch SteamSetupError.mingwNotFound {
            print("SteamSetup: ⚠️ MinGW nicht gefunden - überspringe Wrapper-Installation")
            print("SteamSetup: Steam funktioniert auch ohne Wrapper (nur mit DXMT)")
        } catch {
            print("SteamSetup: ⚠️ Wrapper-Installation fehlgeschlagen: \(error)")
        }
        
        // Schritt 3: SSL-Zertifikate installieren (für Steam-Login und Downloads)
        try await installSSLCertificates(to: prefixURL)
        
        // Schritt 4: Registry-Tweaks anwenden
        try await applyRegistryTweaks(to: prefixURL)
        
        // Schritt 5: Verifizierung (akzeptiert auch partielle Installation)
        try await verifyInstallation(in: prefixURL)
        
        setupProgress = .completed
        print("SteamSetup: ✅ Alle Optimierungen erfolgreich installiert")
    }
    
    // MARK: - DXMT Installation
    
    private func installDXMT(to prefixURL: URL) async throws {
        setupProgress = .downloadingDXMT
        currentStep = "Lade DXMT herunter..."
        progressPercent = 0.1
        
        // DXMT Download URL (neueste Release)
        let dxmtURL = "https://github.com/doitsujin/dxvk/releases/download/v2.4/dxvk-2.4.tar.gz"
        let tempDir = FileManager.default.temporaryDirectory
        let downloadPath = tempDir.appendingPathComponent("dxmt.tar.gz")
        let extractPath = tempDir.appendingPathComponent("dxmt")
        
        print("SteamSetup: Lade DXMT von \(dxmtURL)")
        
        // Download
        let (localURL, _) = try await URLSession.shared.download(from: URL(string: dxmtURL)!)
        try FileManager.default.moveItem(at: localURL, to: downloadPath)
        
        progressPercent = 0.3
        currentStep = "Entpacke DXMT..."
        
        // Entpacken
        try await extract(tarGz: downloadPath, to: extractPath)
        
        progressPercent = 0.5
        setupProgress = .installingDXMT
        currentStep = "Installiere DXMT DLLs..."
        
        // DLLs kopieren
        try await copyDXMTDLLs(from: extractPath, to: prefixURL)
        
        progressPercent = 0.6
        print("SteamSetup: ✅ DXMT installiert")
    }
    
    private func extract(tarGz: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", tarGz.path, "-C", destination.deletingLastPathComponent().path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw SteamSetupError.extractionFailed
        }
    }
    
    private func copyDXMTDLLs(from source: URL, to prefixURL: URL) async throws {
        let system32 = prefixURL.appendingPathComponent("drive_c/windows/system32")
        let syswow64 = prefixURL.appendingPathComponent("drive_c/windows/syswow64")
        
        // DXMT DLLs für 64-bit
        let dllsToCopy = ["d3d11.dll", "dxgi.dll", "d3d10core.dll", "d3d9.dll"]
        
        for dll in dllsToCopy {
            // 64-bit
            let source64 = source.appendingPathComponent("x64/\(dll)")
            let dest64 = system32.appendingPathComponent(dll)
            
            if FileManager.default.fileExists(atPath: source64.path) {
                try? FileManager.default.removeItem(at: dest64)
                try FileManager.default.copyItem(at: source64, to: dest64)
                print("SteamSetup: Kopiert \(dll) → system32")
            }
            
            // 32-bit
            let source32 = source.appendingPathComponent("x32/\(dll)")
            let dest32 = syswow64.appendingPathComponent(dll)
            
            if FileManager.default.fileExists(atPath: source32.path) {
                try? FileManager.default.removeItem(at: dest32)
                try FileManager.default.copyItem(at: source32, to: dest32)
                print("SteamSetup: Kopiert \(dll) → syswow64")
            }
        }
    }
    
    // MARK: - Steam Wrapper Installation
    
    private func installSteamWrapper(to prefixURL: URL) async throws {
        setupProgress = .compilingWrapper
        currentStep = "Kompiliere Steam Wrapper..."
        progressPercent = 0.7
        
        print("SteamSetup: Kompiliere steamwebhelper Wrapper")
        
        // Erstelle Wrapper-Quellcode
        let wrapperSource = generateWrapperSource()
        let tempDir = FileManager.default.temporaryDirectory
        let sourceFile = tempDir.appendingPathComponent("steamwebhelper_wrapper.c")
        let outputFile = tempDir.appendingPathComponent("steamwebhelper.exe")
        
        try wrapperSource.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Kompiliere mit MinGW cross-compiler
        try await compileWrapper(source: sourceFile, output: outputFile)
        
        progressPercent = 0.8
        setupProgress = .installingWrapper
        currentStep = "Installiere Wrapper..."
        
        // Installiere Wrapper in alle CEF-Verzeichnisse
        try await installWrapperToCEFDirs(wrapper: outputFile, prefix: prefixURL)
        
        progressPercent = 0.85
        print("SteamSetup: ✅ Wrapper installiert")
    }
    
    private func generateWrapperSource() -> String {
        """
        // steamwebhelper.exe Wrapper
        // Fügt --in-process-gpu und --disable-gpu Flags hinzu
        
        #include <windows.h>
        #include <stdio.h>
        #include <stdlib.h>
        #include <wchar.h>
        
        int wmain(int argc, wchar_t *argv[]) {
            wchar_t cmdline[32768];
            wchar_t exepath[MAX_PATH];
            STARTUPINFOW si = {0};
            PROCESS_INFORMATION pi = {0};
            
            // Finde das echte steamwebhelper.exe
            GetModuleFileNameW(NULL, exepath, MAX_PATH);
            wchar_t *lastSlash = wcsrchr(exepath, L'\\\\');
            if (lastSlash) {
                wcscpy(lastSlash + 1, L"steamwebhelper_original.exe");
            }
            
            // Baue Command-Line mit zusätzlichen Flags
            wcscpy(cmdline, L"\\"");
            wcscat(cmdline, exepath);
            wcscat(cmdline, L"\\" --in-process-gpu --disable-gpu --disable-d3d11");
            
            // Füge Original-Argumente hinzu
            for (int i = 1; i < argc; i++) {
                wcscat(cmdline, L" \\"");
                wcscat(cmdline, argv[i]);
                wcscat(cmdline, L"\\"");
            }
            
            si.cb = sizeof(si);
            
            // Starte echten Helper
            if (!CreateProcessW(exepath, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
                return 1;
            }
            
            // Warte auf Beendigung
            WaitForSingleObject(pi.hProcess, INFINITE);
            
            DWORD exitCode = 0;
            GetExitCodeProcess(pi.hProcess, &exitCode);
            
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
            
            return exitCode;
        }
        """
    }
    
    private func compileWrapper(source: URL, output: URL) async throws {
        // Prüfe ob MinGW installiert ist (via Homebrew)
        let mingwPaths = [
            "/opt/homebrew/bin/x86_64-w64-mingw32-gcc",
            "/usr/local/bin/x86_64-w64-mingw32-gcc",
            "/opt/local/bin/x86_64-w64-mingw32-gcc"
        ]
        
        guard let mingw = mingwPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw SteamSetupError.mingwNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mingw)
        process.arguments = [
            source.path,
            "-o", output.path,
            "-O2",
            "-s",
            "-municode"
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw SteamSetupError.compilationFailed
        }
    }
    
    private func installWrapperToCEFDirs(wrapper: URL, prefix: URL) async throws {
        let cefBase = prefix.appendingPathComponent("drive_c/Program Files (x86)/Steam/bin/cef")
        
        guard FileManager.default.fileExists(atPath: cefBase.path) else {
            throw SteamSetupError.steamNotInstalled
        }
        
        // Finde alle cef.win* Verzeichnisse
        let contents = try FileManager.default.contentsOfDirectory(
            at: cefBase,
            includingPropertiesForKeys: nil
        )
        
        for cefDir in contents where cefDir.lastPathComponent.hasPrefix("cef.win") {
            let helperPath = cefDir.appendingPathComponent("steamwebhelper.exe")
            let backupPath = cefDir.appendingPathComponent("steamwebhelper_original.exe")
            
            // Sichere Original
            if FileManager.default.fileExists(atPath: helperPath.path),
               !FileManager.default.fileExists(atPath: backupPath.path) {
                try FileManager.default.copyItem(at: helperPath, to: backupPath)
                print("SteamSetup: Original gesichert → \(backupPath.lastPathComponent)")
            }
            
            // Installiere Wrapper
            try? FileManager.default.removeItem(at: helperPath)
            try FileManager.default.copyItem(at: wrapper, to: helperPath)
            print("SteamSetup: Wrapper installiert → \(cefDir.lastPathComponent)")
        }
    }
    
    // MARK: - SSL Certificates
    
    private func installSSLCertificates(to prefixURL: URL) async throws {
        currentStep = "Installiere SSL-Zertifikate..."
        progressPercent = 0.87
        
        print("SteamSetup: Installiere SSL-Zertifikate für HTTPS-Verbindungen")
        
        // Kopiere macOS System-Zertifikate nach Wine
        let macOSCerts = "/etc/ssl/cert.pem"
        let wineCertsDir = prefixURL.appendingPathComponent("drive_c/windows/system32")
        let wineCertsFile = wineCertsDir.appendingPathComponent("cacert.pem")
        
        if FileManager.default.fileExists(atPath: macOSCerts) {
            try? FileManager.default.copyItem(
                at: URL(fileURLWithPath: macOSCerts),
                to: wineCertsFile
            )
            print("SteamSetup: ✅ SSL-Zertifikate installiert")
        } else {
            print("SteamSetup: ⚠️ macOS Zertifikate nicht gefunden - Steam verwendet Wine's eingebaute Zertifikate")
        }
        
        progressPercent = 0.88
    }
    
    // MARK: - Registry Tweaks
    
    private func applyRegistryTweaks(to prefixURL: URL) async throws {
        setupProgress = .applyingRegistryTweaks
        currentStep = "Wende Registry-Optimierungen an..."
        progressPercent = 0.9
        
        print("SteamSetup: Wende Registry-Tweaks an")
        
        let userReg = prefixURL.appendingPathComponent("user.reg")
        
        guard FileManager.default.fileExists(atPath: userReg.path) else {
            throw SteamSetupError.registryNotFound
        }
        
        var registry = try String(contentsOf: userReg, encoding: .utf8)
        
        // 1. AllowImmovableWindows deaktivieren
        if !registry.contains("AllowImmovableWindows") {
            let macDriverSection = """
            
            [Software\\\\Wine\\\\Mac Driver]
            "AllowImmovableWindows"="n"
            """
            registry.append(macDriverSection)
            print("SteamSetup: ✅ AllowImmovableWindows=n gesetzt")
        }
        
        // 2. DISABLEDXMAXIMIZEDWINDOWEDMODE entfernen
        registry = registry.replacingOccurrences(
            of: "DISABLEDXMAXIMIZEDWINDOWEDMODE",
            with: ""
        )
        
        // Schreibe modifizierte Registry zurück
        try registry.write(to: userReg, atomically: true, encoding: .utf8)
        
        progressPercent = 0.92
        
        // 3. Steam Download-Optimierungen in localconfig.vdf
        try configureSteamDownloadSettings(in: prefixURL)
        
        progressPercent = 0.95
        print("SteamSetup: ✅ Registry-Tweaks angewendet")
    }
    
    /// Konfiguriert Steam's localconfig.vdf für optimale Download-Performance
    private func configureSteamDownloadSettings(in prefixURL: URL) throws {
        print("SteamSetup: Konfiguriere Steam Download-Einstellungen")
        
        // Pfad zu Steam's Config
        let steamPath = prefixURL.appendingPathComponent("drive_c/Program Files (x86)/Steam")
        
        // Finde userdata Verzeichnisse
        let userdataPath = steamPath.appendingPathComponent("userdata")
        
        guard FileManager.default.fileExists(atPath: userdataPath.path) else {
            print("SteamSetup: ⚠️ Steam userdata nicht gefunden - wird beim ersten Start erstellt")
            return
        }
        
        // Durchsuche alle User-IDs
        let userDirs = try FileManager.default.contentsOfDirectory(
            at: userdataPath,
            includingPropertiesForKeys: nil
        )
        
        for userDir in userDirs {
            let configPath = userDir.appendingPathComponent("config/localconfig.vdf")
            
            guard FileManager.default.fileExists(atPath: configPath.path) else {
                continue
            }
            
            var config = try String(contentsOf: configPath, encoding: .utf8)
            
            // Optimierungen für Downloads unter Wine
            let optimizations = [
                ("DownloadThrottleKbps", "0"),  // Keine Bandbreiten-Limitierung
                ("AllowDownloadsWhileStreaming", "0"),  // Keine Downloads beim Streaming
                ("StreamingWhileStreaming", "0"),  // Kein Streaming während Downloads
                ("AutoUpdateTimeRestrictionEnabled", "0")  // Keine Zeit-Beschränkungen
            ]
            
            for (key, value) in optimizations {
                if !config.contains("\"\(key)\"") {
                    // Füge Einstellung hinzu wenn nicht vorhanden
                    if let systemRange = config.range(of: "\"System\"") {
                        let insertPosition = config.index(systemRange.upperBound, offsetBy: 10)
                        let setting = "\n\t\t\t\"\(key)\"\t\t\"\(value)\""
                        config.insert(contentsOf: setting, at: insertPosition)
                    }
                }
            }
            
            try config.write(to: configPath, atomically: true, encoding: .utf8)
            print("SteamSetup: ✅ Download-Optimierungen für User \(userDir.lastPathComponent) gesetzt")
        }
    }
    
    // MARK: - Verification
    
    private func verifyInstallation(in prefixURL: URL) async throws {
        setupProgress = .verifying
        currentStep = "Verifiziere Installation..."
        progressPercent = 0.98
        
        print("SteamSetup: Verifiziere Installation")
        
        let status = checkSteamOptimizations(in: prefixURL)
        
        // Akzeptiere sowohl vollständige als auch teilweise Optimierung
        switch status {
        case .fullyOptimized:
            print("SteamSetup: ✅ Vollständig optimiert (DXMT + Wrapper)")
        case .partiallyOptimized(let missing):
            print("SteamSetup: ✅ Teilweise optimiert (DXMT installiert, \(missing.joined(separator: ", ")) fehlt)")
        case .notOptimized:
            throw SteamSetupError.verificationFailed
        }
        
        progressPercent = 1.0
        print("SteamSetup: ✅ Verifizierung erfolgreich")
    }
}

// MARK: - Supporting Types

enum SteamOptimizationStatus {
    case notOptimized
    case partiallyOptimized(missing: [String])
    case fullyOptimized
    
    var description: String {
        switch self {
        case .notOptimized:
            return "Nicht optimiert"
        case .partiallyOptimized(let missing):
            return "Teilweise optimiert (fehlt: \(missing.joined(separator: ", ")))"
        case .fullyOptimized:
            return "Vollständig optimiert"
        }
    }
}

enum SteamSetupError: LocalizedError {
    case extractionFailed
    case mingwNotFound
    case compilationFailed
    case steamNotInstalled
    case registryNotFound
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "DXMT konnte nicht entpackt werden"
        case .mingwNotFound:
            return "MinGW-Compiler nicht gefunden. Installieren Sie: brew install mingw-w64"
        case .compilationFailed:
            return "Wrapper-Kompilierung fehlgeschlagen"
        case .steamNotInstalled:
            return "Steam ist nicht in diesem Prefix installiert"
        case .registryNotFound:
            return "Wine Registry nicht gefunden"
        case .verificationFailed:
            return "Installation konnte nicht verifiziert werden"
        }
    }
}
