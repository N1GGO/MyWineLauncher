//
//  ContentViewModel.swift
//  WineLauncher
//
//  Created by Nico Werner on 30.09.26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ContentViewModel {
    
    init(
        config: Configuration,
        state: LauncherState = .ready
    ) {
        self.state = state
        self.config = config
        self.launcherService = .init(config: config)
        self.applicationRepository = .init()
        
        applications = applicationRepository.all()
        
        // Automatische Steam-Optimierungs-Prüfung
        Task {
            await checkAndSetupSteamOptimizations()
        }
    }
    
    let config: Configuration
    let launcherService: LauncherService
    let applicationRepository: ApplicationRepository
    
    private let bookmarkService = SecurityScopedBookmarkService()
    private let steamGameScanner = SteamGameScanner()
    
    var state: LauncherState
    
    private(set) var selectedApplication: WindowsApplication?
    
    var applications: [WindowsApplication] = []
    var discoveredSteamGames: [SteamGameScanner.SteamGame] = []
    
    func selectApplication(application: WindowsApplication) {
        selectedApplication = application
        
        print(
            "WineLauncher: Windows-App ausgewählt: \(application.name)"
        )
    }
    
    func selectApplication(url: URL) async {
        do {
            let name = url
                .deletingPathExtension()
                .lastPathComponent
            
            let application = try await applicationRepository.application(
                name: name,
                executableURL: url,
                prefixName: name
            )
            
            applicationRepository.add(application)
            reloadApplications()
            
            selectedApplication = application
            
            print(
                "WineLauncher: Windows-App ausgewählt: \(application.name)"
            )
            
        } catch {
            print(
                "WineLauncher: Anwendung konnte nicht hinzugefügt werden – \(error)"
            )
        }
    }
    
    func selectInstalledApplication(url: URL) async {
        guard let selectedApplication else {
            print("WineLauncher: Kein Prefix ausgewählt")
            return
        }

        do {
            let bookmark = try bookmarkService.bookmark(
                for: url
            )

            let application = WindowsApplication(
                executableBookmark: bookmark,
                name: url
                    .deletingPathExtension()
                    .lastPathComponent,
                executableURL: url,
                prefixName: selectedApplication.prefixName,
                prefixURL: selectedApplication.prefixURL
            )

            applicationRepository.add(application)
            reloadApplications()

            self.selectedApplication = application

            print(
                "WineLauncher: Installierte Anwendung ausgewählt: \(application.name)"
            )

        } catch {
            print(
                "WineLauncher: Installierte Anwendung konnte nicht hinzugefügt werden – \(error)"
            )
        }
    }

    
    func removeApplication(_ application: WindowsApplication) {
        applicationRepository.remove(application)
        
        if selectedApplication?.id == application.id {
            selectedApplication = nil
        }
        
        reloadApplications()
    }
    
    func start() {
        guard let application = selectedApplication else {
            print("WineLauncher: Keine Windows-App ausgewählt")
            return
        }
        
        state = .starting
        
        Task {
            let accessing = bookmarkService.startAccessing(
                application.executableURL
            )
            
            print(
                "WineLauncher: Security-Scoped-Zugriff: \(accessing)"
            )
            
            defer {
                if accessing {
                    bookmarkService.stopAccessing(
                        application.executableURL
                    )
                }
            }
            
            await launcherService.start(application: application) {
                self.state = .running
            } onEnded: {
                status, wasKilled in Task {
                    @MainActor in self.state = wasKilled ? .killed : .ended(status: status)
                }
            }
            
        }
    }
    
    func stop() {
        Task {
            await launcherService.stop()

        }
    }
    
    private func reloadApplications() {
        applications = applicationRepository.all()
    }
    
    /// Scannt Steam-Bibliotheken nach installierten Spielen
    func scanForSteamGames() async {
        print("WineLauncher: Scanne nach Steam-Spielen...")
        
        // Finde alle Steam-Prefixes
        let steamApps = applications.filter {
            $0.executableURL.lastPathComponent.lowercased() == "steam.exe"
        }
        
        guard !steamApps.isEmpty else {
            print("WineLauncher: Keine Steam-Installation gefunden")
            return
        }
        
        var allGames: [SteamGameScanner.SteamGame] = []
        
        for steamApp in steamApps {
            do {
                let games = try steamGameScanner.scanAllGames(in: steamApp.prefixURL)
                allGames.append(contentsOf: games)
                print("WineLauncher: \(games.count) Spiele in '\(steamApp.name)' gefunden")
            } catch {
                print("WineLauncher: Fehler beim Scannen von '\(steamApp.name)': \(error)")
            }
        }
        
        // Entferne Duplikate (falls mehrere Steam-Prefixes)
        discoveredSteamGames = Array(Set(allGames))
        
        print("WineLauncher: ✅ Insgesamt \(discoveredSteamGames.count) Steam-Spiele gefunden")
    }
    
    /// Fügt ein gefundenes Steam-Spiel als Anwendung hinzu
    func addSteamGameToLauncher(_ game: SteamGameScanner.SteamGame) async {
        do {
            // Finde den entsprechenden Steam-Prefix
            guard let steamApp = applications.first(where: {
                $0.executableURL.lastPathComponent.lowercased() == "steam.exe"
            }) else {
                print("WineLauncher: Steam-Prefix nicht gefunden")
                return
            }
            
            // Erstelle Bookmark
            let bookmark = try bookmarkService.bookmark(for: game.executablePath)
            
            // Erstelle WindowsApplication
            let application = WindowsApplication(
                executableBookmark: bookmark,
                name: game.name,
                executableURL: game.executablePath,
                prefixName: steamApp.prefixName,
                prefixURL: steamApp.prefixURL,
                arguments: []  // Spiele brauchen meist keine Extra-Argumente
            )
            
            applicationRepository.add(application)
            reloadApplications()
            
            print("WineLauncher: ✅ '\(game.name)' zum Launcher hinzugefügt")
        } catch {
            print("WineLauncher: Fehler beim Hinzufügen von '\(game.name)': \(error)")
        }
    }
    
    /// Prüft ob Steam-Optimierungen bereits installiert sind und installiert ggf. automatisch
    private func checkAndSetupSteamOptimizations() async {
        let steamApps = applications.filter { 
            $0.executableURL.lastPathComponent.lowercased() == "steam.exe" 
        }
        
        guard !steamApps.isEmpty else {
            return
        }
        
        let setupService = SteamSetupService()
        
        for steamApp in steamApps {
            let status = setupService.checkSteamOptimizations(in: steamApp.prefixURL)
            
            switch status {
            case .notOptimized:
                print("WineLauncher: Steam nicht optimiert → installiere DXMT automatisch")
                
                do {
                    try await setupService.setupSteamOptimizations(for: steamApp.prefixURL)
                    print("WineLauncher: ✅ Steam automatisch optimiert")
                } catch {
                    print("WineLauncher: ⚠️ Automatische Optimierung fehlgeschlagen: \(error.localizedDescription)")
                }
                
            case .partiallyOptimized(let missing):
                print("WineLauncher: Steam teilweise optimiert (fehlt: \(missing.joined(separator: ", ")))")
                
            case .fullyOptimized:
                print("WineLauncher: ✅ Steam bereits optimiert")
            }
        }
    }
}
