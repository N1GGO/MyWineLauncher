import Foundation

struct WindowsApplication: Identifiable, Codable {
    let id: UUID
    let name: String
    let executableURL: URL
    let executableBookmark: Data
    let prefixName: String
    let prefixURL: URL
    let arguments: [String]

    init(
        id: UUID = UUID(),
        name: String,
        executableURL: URL,
        executableBookmark: Data,
        prefixName: String,
        prefixURL: URL,
        arguments: [String] = []
    ) {
        self.id = id
        self.name = name
        self.executableURL = executableURL
        self.executableBookmark = executableBookmark
        self.prefixName = prefixName
        self.prefixURL = prefixURL
        self.arguments = arguments
    }

    func withExecutableURL(_ url: URL) -> WindowsApplication {
        WindowsApplication(
            id: id,
            name: name,
            executableURL: url,
            executableBookmark: executableBookmark,
            prefixName: prefixName,
            prefixURL: prefixURL,
            arguments: arguments
        )
    }
}
