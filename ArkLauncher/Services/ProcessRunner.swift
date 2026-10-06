//
//  ProcessRunner.swift
//  WineLauncher
//
//  Created by Nico Werner on 02.10.26.
//

import Foundation

actor ProcessRunner {

    private var process: Process?
    private var stopRequested = false

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:],
        onStarted: (@Sendable () -> Void)? = nil,
        onTerminated: (@Sendable (Int32, Bool) -> Void)? = nil
    ) async throws -> ProcessResult {

        let process = Process()

        self.process = process
        self.stopRequested = false

        process.executableURL = executableURL
        process.arguments = arguments

        var processEnvironment = ProcessInfo.processInfo.environment

        environment.forEach { key, value in
            processEnvironment[key] = value
        }

        process.environment = processEnvironment

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try await withCheckedThrowingContinuation { continuation in

            process.terminationHandler = { [weak self] process in

                Task {
                    let wasKilled = await self?.handleTermination(
                        status: process.terminationStatus
                    ) ?? false

                    onTerminated?(
                        process.terminationStatus,
                        wasKilled
                    )

                    continuation.resume()
                }
            }

            do {
                try process.run()

                onStarted?()

            } catch {
                self.clearProcess()

                continuation.resume(
                    throwing: error
                )
            }
        }

        let outputData = outputPipe.fileHandleForReading
            .readDataToEndOfFile()

        let errorData = errorPipe.fileHandleForReading
            .readDataToEndOfFile()

        return ProcessResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(
                data: outputData,
                encoding: .utf8
            ) ?? "",
            standardError: String(
                data: errorData,
                encoding: .utf8
            ) ?? ""
        )
    }

    func stop() {

        guard let process else {
            return
        }

        guard process.isRunning else {
            return
        }

        stopRequested = true

        process.terminate()
        
    }

    private func handleTermination(
        status: Int32
    ) -> Bool {

        let wasKilled = stopRequested

        process = nil
        stopRequested = false

        return wasKilled
    }

    private func clearProcess() {
        process = nil
        stopRequested = false
    }
}
