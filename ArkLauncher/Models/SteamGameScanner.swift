//
//  SteamGameScanner.swift
//  WineLauncher
//
//  Created by Nico Werner on 04.10.26.
//

import Foundation

/// Scannt Steam-Bibliotheken und findet installierte Spiele
@MainActor
final class SteamGameScanner {
    
    struct SteamGame: Identifiable, Hashable {
        let id: String  // App-ID
        let name: String
        let installDir: String
        let executablePath: URL
        let libraryPath: URL
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: SteamGame, rhs: SteamGame) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    /// Findet alle Steam-Bibliotheken in einem Wine-Prefix
    func findSteamLibraries(in prefixURL: URL) throws -> [URL] {
        var libraries: [URL] = []
        
        // Haupt-Steam-Verzeichnis
        let mainSteamPath = prefixURL.appendingPathComponent("drive_c/Program Files (x86)/Steam")
        
        guard FileManager.default.fileExists(atPath: mainSteamPath.path) else {
            print("SteamScanner: Steam nicht im Prefix gefunden")
            return []
        }
        
        // Standard-Bibliothek
        let steamApps = mainSteamPath.appendingPathComponent("steamapps")
        if FileManager.default.fileExists(atPath: steamApps.path) {
            libraries.append(steamApps)
        }
        
        // Zusätzliche Bibliotheken aus libraryfolders.vdf
        let libraryFoldersFile = steamApps.appendingPathComponent("libraryfolders.vdf")
        
        if FileManager.default.fileExists(atPath: libraryFoldersFile.path) {
            let additionalLibraries = try parseLibraryFolders(file: libraryFoldersFile)
            libraries.append(contentsOf: additionalLibraries)
        }
        
        print("SteamScanner: \(libraries.count) Bibliothek(en) gefunden")
        return libraries
    }
    
    /// Scannt eine Bibliothek nach installierten Spielen
    func scanLibrary(at libraryURL: URL) throws -> [SteamGame] {
        var games: [SteamGame] = []
        
        // Finde alle .acf Manifest-Dateien
        let contents = try FileManager.default.contentsOfDirectory(
            at: libraryURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        
        for file in contents where file.pathExtension == "acf" {
            if let game = try? parseAppManifest(file: file, libraryPath: libraryURL) {
                games.append(game)
            }
        }
        
        print("SteamScanner: \(games.count) Spiel(e) in \(libraryURL.lastPathComponent) gefunden")
        return games
    }
    
    /// Scannt alle Bibliotheken in einem Prefix
    func scanAllGames(in prefixURL: URL) throws -> [SteamGame] {
        let libraries = try findSteamLibraries(in: prefixURL)
        var allGames: [SteamGame] = []
        
        for library in libraries {
            let games = try scanLibrary(at: library)
            allGames.append(contentsOf: games)
        }
        
        print("SteamScanner: Insgesamt \(allGames.count) Spiel(e) gefunden")
        return allGames
    }
    
    // MARK: - Private Parsing
    
    private func parseLibraryFolders(file: URL) throws -> [URL] {
        let content = try String(contentsOf: file, encoding: .utf8)
        var libraries: [URL] = []
        
        // Einfaches Parsing von libraryfolders.vdf
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("\"path\"") {
                // Extrahiere Pfad: "path"		"C:\\Program Files (x86)\\Steam"
                let components = line.components(separatedBy: "\"")
                if components.count >= 4 {
                    let windowsPath = components[3]
                    // Konvertiere Windows-Pfad zu macOS-Pfad
                    if let url = convertWindowsPath(windowsPath, basePrefix: file) {
                        let steamAppsPath = url.appendingPathComponent("steamapps")
                        if FileManager.default.fileExists(atPath: steamAppsPath.path) {
                            libraries.append(steamAppsPath)
                        }
                    }
                }
            }
        }
        
        return libraries
    }
    
    private func parseAppManifest(file: URL, libraryPath: URL) throws -> SteamGame? {
        let content = try String(contentsOf: file, encoding: .utf8)
        
        var appID: String?
        var name: String?
        var installDir: String?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("\"appid\"") {
                appID = extractValue(from: trimmed)
            } else if trimmed.contains("\"name\"") {
                name = extractValue(from: trimmed)
            } else if trimmed.contains("\"installdir\"") {
                installDir = extractValue(from: trimmed)
            }
        }
        
        guard let appID = appID,
              let name = name,
              let installDir = installDir else {
            return nil
        }
        
        // Finde die .exe Datei
        let gamePath = libraryPath.appendingPathComponent("common/\(installDir)")
        
        guard let executable = findGameExecutable(in: gamePath, gameName: name) else {
            print("SteamScanner: ⚠️ Executable für '\(name)' nicht gefunden")
            return nil
        }
        
        return SteamGame(
            id: appID,
            name: name,
            installDir: installDir,
            executablePath: executable,
            libraryPath: libraryPath
        )
    }
    
    private func findGameExecutable(in gamePath: URL, gameName: String) -> URL? {
        guard FileManager.default.fileExists(atPath: gamePath.path) else {
            return nil
        }
        
        // Strategie 1: Suche nach .exe mit gleichem Namen
        let nameBasedExe = gamePath.appendingPathComponent("\(gameName).exe")
        if FileManager.default.fileExists(atPath: nameBasedExe.path) {
            return nameBasedExe
        }
        
        // Strategie 2: Suche alle .exe Dateien (max depth 2)
        if let exes = try? findExecutables(in: gamePath, maxDepth: 2) {
            // Bevorzuge .exe im Root-Verzeichnis
            let rootExes = exes.filter { $0.deletingLastPathComponent() == gamePath }
            if !rootExes.isEmpty {
                return rootExes.first
            }
            
            // Sonst irgendeine .exe
            return exes.first
        }
        
        return nil
    }
    
    private func findExecutables(in directory: URL, maxDepth: Int) throws -> [URL] {
        guard maxDepth > 0 else { return [] }
        
        var executables: [URL] = []
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey]
        )
        
        for item in contents {
            let resourceValues = try item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            
            if resourceValues.isRegularFile == true && item.pathExtension.lowercased() == "exe" {
                executables.append(item)
            } else if resourceValues.isDirectory == true && maxDepth > 1 {
                let subExecutables = try findExecutables(in: item, maxDepth: maxDepth - 1)
                executables.append(contentsOf: subExecutables)
            }
        }
        
        return executables
    }
    
    private func extractValue(from line: String) -> String? {
        let components = line.components(separatedBy: "\"")
        guard components.count >= 4 else { return nil }
        return components[3]
    }
    
    private func convertWindowsPath(_ windowsPath: String, basePrefix: URL) -> URL? {
        // Konvertiere "C:\\Program Files\\..." zu macOS Pfad
        let normalized = windowsPath.replacingOccurrences(of: "\\\\", with: "/")
        
        // Finde Prefix root
        var current = basePrefix
        while current.lastPathComponent != "drive_c" && current.path != "/" {
            current = current.deletingLastPathComponent()
        }
        
        if current.path == "/" {
            return nil
        }
        
        let prefixRoot = current.deletingLastPathComponent()
        
        // Entferne "C:" und baue Pfad
        let pathWithoutDrive = normalized.components(separatedBy: "/").dropFirst().joined(separator: "/")
        
        return prefixRoot.appendingPathComponent("drive_c/\(pathWithoutDrive)")
    }
}
