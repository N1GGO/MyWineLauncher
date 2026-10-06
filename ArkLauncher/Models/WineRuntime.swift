//
//  WineRuntime.swift
//  WineLauncher
//
//  Created by Nico Werner on 02.10.26.
//

import Foundation

final class WineRuntime {

    private let processRunner: ProcessRunner

    private let wineExecutable = URL(
        fileURLWithPath: "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine"
    )
    
    // Alternative: CrossOver (falls installiert)
    private let crossoverExecutable = URL(
        fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    )

    init(
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.processRunner = processRunner
        
        // Unterdrücke SQLite-Warnings
        setenv("SQLITE_TMPDIR", NSTemporaryDirectory(), 1)
        
        // Prüfe welche Wine-Version verfügbar ist
        if FileManager.default.fileExists(atPath: crossoverExecutable.path) {
            print("WineLauncher: CrossOver erkannt (bessere Steam-Unterstützung)")
        } else if FileManager.default.fileExists(atPath: wineExecutable.path) {
            print("WineLauncher: Wine Stable erkannt")
        } else {
            print("WineLauncher: ⚠️ Keine Wine-Installation gefunden")
        }
    }
    
    // Wählt die beste verfügbare Wine-Binary
    private func getWineExecutable() -> URL {
        // Bevorzuge CrossOver falls vorhanden
        if FileManager.default.fileExists(atPath: crossoverExecutable.path) {
            return crossoverExecutable
        }
        return wineExecutable
    }

    func run(
        application: WindowsApplication,
        onStarted: (@Sendable () -> Void)? = nil,
        onTerminated: (@Sendable (Int32, Bool) -> Void)? = nil
    ) async throws -> ProcessResult {
        
        // Steam-spezifische Konfiguration
        let isSteam = application.executableURL.lastPathComponent.lowercased() == "steam.exe"
        
        // Umgebungsvariablen
        var environment: [String: String] = [
            "WINEPREFIX": application.prefixURL.path,
            "WINEDEBUG": "-all"
        ]
        
        // Steam-spezifische Konfiguration
        if isSteam {
            print("WineLauncher: 🎮 Steam-Start erkannt")
            
            // PRAGMATISCH: Verwende das funktionierende launch-steam.sh Skript
            let launchScriptPath = "/Users/nicowerner/Downloads/steam-on-m1-wine/scripts/launch-steam.sh"
            
            if FileManager.default.fileExists(atPath: launchScriptPath) {
                print("WineLauncher: Verwende launch-steam.sh (funktioniert garantiert)")
                
                // Setze WINEPREFIX für das Skript
                var scriptEnv = ProcessInfo.processInfo.environment
                scriptEnv["WINEPREFIX"] = application.prefixURL.path
                
                let result = try await processRunner.run(
                    executableURL: URL(fileURLWithPath: "/bin/bash"),
                    arguments: [launchScriptPath],
                    environment: scriptEnv,
                    onStarted: {
                        print("WineLauncher: ✅ Steam gestartet")
                        onStarted?()
                    },
                    onTerminated: { code, wasKilled in
                        print("WineLauncher: Steam beendet (Code: \(code))")
                        onTerminated?(code, wasKilled)
                    }
                )
                
                return result
            }
            
            // FALLBACK: Eigene Implementierung (falls Skript nicht gefunden)
            print("WineLauncher: ⚠️ launch-steam.sh nicht gefunden → Fallback-Modus")
            
            // Töte alte wineserver-Prozesse
            await killWineServer(for: application.prefixURL)
            
            // Bereinige Lock-Dateien
            print("WineLauncher: Bereinige Chromium-Locks...")
            cleanupChromiumLocks(in: application.prefixURL)
            
            // Steam-Umgebungsvariablen
            environment["WINEDLLOVERRIDES"] = "mscoree=d;mshtml=d;winemac.drv=b"
            environment["MTL_HUD_ENABLED"] = "1"
            
            // Erkenne DXVK/DXMT
            let system32 = application.prefixURL.appendingPathComponent("drive_c/windows/system32")
            let hasDXVK = FileManager.default.fileExists(atPath: system32.appendingPathComponent("dxgi.dll").path)
            
            if hasDXVK {
                environment["DXVK_HUD"] = "compiler"
                print("WineLauncher: ✅ DXVK/DXMT erkannt")
            }
            
            // Big Picture Mode als sicherste Option
            let steamArgs = ["-bigpicture", "-silent"]
            print("WineLauncher: Starte Big Picture Mode")
            
            let wineExec = getWineExecutable()
            let result = try await processRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
                arguments: [
                    "-x86_64",
                    wineExec.path,
                    application.executableURL.path
                ] + steamArgs,
                environment: environment,
                onStarted: {
                    print("WineLauncher: ✅ Steam gestartet")
                    onStarted?()
                },
                onTerminated: { code, wasKilled in
                    print("WineLauncher: Steam beendet (Code: \(code))")
                    onTerminated?(code, wasKilled)
                }
            )
            
            return result
        }
        
        // Nicht-Steam Anwendungen
        environment["WINEDLLOVERRIDES"] = "dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d"
        
        var wineArguments = [application.executableURL.path] + application.arguments

        return try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
            arguments: [
                "-x86_64",
                getWineExecutable().path
            ] + wineArguments,
            environment: environment,
            onStarted: onStarted,
            onTerminated: onTerminated
        )
    }
    
    /// Erkennt die Display-Größe für Wine Virtual Desktop (wie im Skript Zeile 274-287)
    private func detectDisplaySize() -> String {
        let script = """
        tell application "Finder" to get bounds of window of desktop
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Format: "0, 0, WIDTH, HEIGHT"
                let components = output.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if components.count == 4,
                   let width = Int(components[2]),
                   let height = Int(components[3]),
                   width > 0 && height > 0 {
                    return "\(width)x\(height)"
                }
            }
        } catch {
            print("WineLauncher: Display-Größenerkennung fehlgeschlagen: \(error)")
        }
        
        // Fallback: 1440x900 (13" Retina MacBook)
        return "1440x900"
    }
    
    /// Steam Launch-Modi
    private enum SteamLaunchMode {
        case bigPicture    // Controller-UI, am zuverlässigsten
        case smallMode     // Kompakte Liste ohne Browser
        case traditional   // Standard-UI mit CEF
    }
    
    /// Bestimmt den besten Steam-Startmodus basierend auf Prefix-Konfiguration
    private func determineSteamLaunchMode(prefix: URL) -> SteamLaunchMode {
        // Prüfe auf DXMT-Installation
        let hasDXMT = FileManager.default.fileExists(
            atPath: prefix.appendingPathComponent("drive_c/windows/system32/d3d11.dll").path
        )
        
        // Prüfe auf Custom Wrapper (aus steam-on-m1-wine)
        let hasWrapper = FileManager.default.fileExists(
            atPath: prefix.appendingPathComponent("drive_c/Program Files (x86)/Steam/bin/cef/cef.win7x64/steamwebhelper.exe").path
        )
        
        if hasDXMT && hasWrapper {
            print("WineLauncher: DXMT + Wrapper erkannt → Traditional Mode")
            return .traditional
        } else if hasDXMT {
            print("WineLauncher: Nur DXMT erkannt → Big Picture Mode")
            return .bigPicture
        } else {
            print("WineLauncher: Keine Optimierungen → Big Picture Mode (sicherste Option)")
            return .bigPicture
        }
    }
    
    /// Tötet den wineserver für ein bestimmtes Prefix
    private func killWineServer(for prefixURL: URL) async {
        print("WineLauncher: Beende wineserver für Prefix...")
        
        let wineServerPath = getWineExecutable()
            .deletingLastPathComponent()
            .appendingPathComponent("wineserver")
        
        guard FileManager.default.fileExists(atPath: wineServerPath.path) else {
            print("WineLauncher: wineserver nicht gefunden")
            return
        }
        
        let killProcess = Process()
        killProcess.executableURL = wineServerPath
        killProcess.arguments = ["-k"]  // -k = kill all processes
        killProcess.environment = [
            "WINEPREFIX": prefixURL.path
        ]
        killProcess.standardOutput = Pipe()
        killProcess.standardError = Pipe()
        
        do {
            try killProcess.run()
            killProcess.waitUntilExit()
            
            // Warte kurz, damit Prozesse sauber terminieren
            try? await Task.sleep(for: .milliseconds(500))
            
            print("WineLauncher: ✅ wineserver beendet")
        } catch {
            print("WineLauncher: Fehler beim Beenden von wineserver: \(error)")
        }
    }
    
    /// Bereinigt Chromium Singleton-Locks (verhindert schwarzes Fenster - Skript Zeile 90-98)
    private func cleanupChromiumLocks(in prefixURL: URL) {
        // Pfad zum Steam htmlcache (analog zum Skript)
        let username = ProcessInfo.processInfo.environment["USER"] ?? "crossover"
        let htmlcachePath = prefixURL
            .appendingPathComponent("drive_c/users/\(username)/AppData/Local/Steam/htmlcache")
        
        guard FileManager.default.fileExists(atPath: htmlcachePath.path) else {
            return
        }
        
        do {
            // Suche nach Singleton* und *.lock Dateien
            let enumerator = FileManager.default.enumerator(
                at: htmlcachePath,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            var deletedCount = 0
            while let fileURL = enumerator?.nextObject() as? URL {
                let filename = fileURL.lastPathComponent
                
                // Lösche Singleton*, *.lock und CrashpadMetrics*.pma
                if filename.hasPrefix("Singleton") ||
                   filename.hasSuffix(".lock") ||
                   (filename.hasPrefix("CrashpadMetrics") && filename.hasSuffix(".pma")) {
                    try? FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("WineLauncher: \(deletedCount) Chromium Lock-Dateien bereinigt")
            }
        } catch {
            print("WineLauncher: Fehler beim Bereinigen der Lock-Dateien: \(error)")
        }
    }
    
    func stop() async {
        await processRunner.stop()
    }

    func initializePrefix(
        at prefix: URL
    ) async throws -> ProcessResult {

        return try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
            arguments: [
                "-x86_64",
                getWineExecutable().path,
                "wineboot"
            ],
            environment: [
                "WINEPREFIX": prefix.path
            ]
        )
    }
}
