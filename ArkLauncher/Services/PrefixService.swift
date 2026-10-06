//
//  PrefixService.swift
//  WineLauncher
//
//  Created by Nico Werner on 02.10.26.
//

import Foundation

final class PrefixService {

    private let prefixesDirectory: URL
    private let wineRuntime: WineRuntime

    init(
        wineRuntime: WineRuntime = WineRuntime()
    ) {
        self.prefixesDirectory = URL(
            fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support/WineWrapper/Prefixes"
        )

        self.wineRuntime = wineRuntime
    }

    func prefix(named name: String) -> URL {
        prefixesDirectory
            .appendingPathComponent(name, isDirectory: true)
    }

    func exists(named name: String) -> Bool {
        let prefixURL = prefix(named: name)

        return FileManager.default.fileExists(
            atPath: prefixURL.path
        )
    }

    func initialize(named name: String) async throws {

        let prefixURL = prefix(named: name)

        try FileManager.default.createDirectory(
            at: prefixURL,
            withIntermediateDirectories: true
        )

        let result = try await wineRuntime.initializePrefix(
            at: prefixURL
        )

        if result.terminationStatus != 0 {
            throw PrefixServiceError.initializationFailed(
                result.standardError
            )
        }
    }
    
    func getOrCreate(named name: String) async throws -> URL {

        let prefixURL = prefix(named: name)

        if exists(named: name) {
            return prefixURL
        }

        try await initialize(named: name)

        return prefixURL
    }
    
    func driveC(named name: String) -> URL {
        prefix(named: name)
            .appendingPathComponent("drive_c", isDirectory: true)
    }

    
}

enum PrefixServiceError: Error {
    case initializationFailed(String)
}
