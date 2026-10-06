import Foundation

final class ApplicationStore {
    private let fileURL: URL

    init() {
        let applicationSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let directory = applicationSupport
            .appendingPathComponent("WineWrapper", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        self.fileURL = directory.appendingPathComponent("applications.json")
    }

    func load() throws -> [WindowsApplication] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([WindowsApplication].self, from: data)
    }

    func save(_ applications: [WindowsApplication]) throws {
        let data = try JSONEncoder().encode(applications)
        try data.write(to: fileURL, options: .atomic)
    }
}
