import Foundation

final class WineRuntime {
    private let processRunner: ProcessRunner
    private let wineExecutable = URL(
        fileURLWithPath: "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine"
    )

    init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    func run(
        application: WindowsApplication,
        onStarted: (@Sendable () -> Void)? = nil,
        onTerminated: (@Sendable (Int32, Bool) -> Void)? = nil
    ) async throws -> ProcessResult {
        let wineArguments = [
            application.executableURL.path,
            "-no-cef-sandbox",
            "-cef-single-process",
            "-noverifyfiles"
        ] + application.arguments

        return try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
            arguments: [
                "-x86_64",
                wineExecutable.path
            ] + wineArguments,
            environment: [
                "WINEPREFIX": application.prefixURL.path,
                "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d"
            ],
            onStarted: onStarted,
            onTerminated: onTerminated
        )
    }

    func initializePrefix(at prefix: URL) async throws -> ProcessResult {
        return try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
            arguments: [
                "-x86_64",
                wineExecutable.path,
                "wineboot"
            ],
            environment: [
                "WINEPREFIX": prefix.path
            ]
        )
    }

    func stop() async {
        await processRunner.stop()
    }
}
