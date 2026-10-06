import Foundation

final class LauncherService {
    private let config: Configuration
    private let wineRuntime: WineRuntime

    init(config: Configuration, wineRuntime: WineRuntime = WineRuntime()) {
        self.config = config
        self.wineRuntime = wineRuntime
    }

    func start(
        application: WindowsApplication,
        onStarted: @escaping @Sendable () -> Void,
        onEnded: @escaping @Sendable (Int32, Bool) -> Void
    ) async {
        do {
            print("WineLauncher: Starte \(application.name): \(application.executableURL.path)")
            let result = try await wineRuntime.run(
                application: application,
                onStarted: { onStarted() },
                onTerminated: { terminationStatus, wasKilled in
                    onEnded(terminationStatus, wasKilled)
                }
            )
            print("WineLauncher: \(application.name) beendet mit Code \(result.terminationStatus)")
            if !result.standardOutput.isEmpty {
                print("Wine stdout:")
                print(result.standardOutput)
            }
            if !result.standardError.isEmpty {
                print("Wine stderr:")
                print(result.standardError)
            }
        } catch {
            print("WineLauncher: \(application.name) konnte nicht gestartet werden – \(error)")
        }
    }

    func stop() async {
        await wineRuntime.stop()
    }
}
