import Foundation
import Observation

@Observable
@MainActor
final class ContentViewModel {
    init(config: Configuration, state: LauncherState = .ready) {
        self.state = state
        self.config = config
        self.launcherService = .init(config: config)
        self.applicationRepository = .init()
        applications = applicationRepository.all()
    }

    let config: Configuration
    let launcherService: LauncherService
    let applicationRepository: ApplicationRepository

    private let bookmarkService = SecurityScopedBookmarkService()

    var state: LauncherState
    private(set) var selectedApplication: WindowsApplication?
    var applications: [WindowsApplication] = []

    func selectApplication(application: WindowsApplication) {
        selectedApplication = application
        print("WineLauncher: Windows-App ausgewählt: \(application.name)")
    }

    func selectApplication(url: URL) async {
        do {
            let name = url.deletingPathExtension().lastPathComponent
            let application = try await applicationRepository.application(
                name: name,
                executableURL: url,
                prefixName: name
            )
            applicationRepository.add(application)
            reloadApplications()
            selectedApplication = application
            print("WineLauncher: Windows-App ausgewählt: \(application.name)")
        } catch {
            print("WineLauncher: Anwendung konnte nicht hinzugefügt werden – \(error)")
        }
    }

    func start() {
        guard let application = selectedApplication else {
            print("WineLauncher: Keine Windows-App ausgewählt")
            return
        }
        state = .starting
        Task {
            let accessing = bookmarkService.startAccessing(application.executableURL)
            print("WineLauncher: Security-Scoped-Zugriff: \(accessing)")
            defer {
                if accessing {
                    bookmarkService.stopAccessing(application.executableURL)
                }
            }
            await launcherService.start(
                application: application,
                onStarted: {
                    Task { @MainActor in self.state = .running }
                },
                onEnded: { _, wasKilled in
                    Task { @MainActor in
                        self.state = wasKilled ? .killed : .ended
                    }
                }
            )
        }
    }

    func stop() {
        Task { await launcherService.stop() }
    }

    func removeApplication(_ application: WindowsApplication) {
        applicationRepository.remove(application)
        if selectedApplication?.id == application.id {
            selectedApplication = nil
        }
        reloadApplications()
    }

    private func reloadApplications() {
        applications = applicationRepository.all()
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
                name: url
                    .deletingPathExtension()
                    .lastPathComponent,
                executableURL: url,
                executableBookmark: bookmark,
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
}
