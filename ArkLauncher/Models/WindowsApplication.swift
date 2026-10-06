//
//  Application.swift
//  WineLauncher
//
//  Created by Nico Werner on 02.10.26.
//

import Foundation

import Foundation

struct WindowsApplication: Identifiable, Codable {

    let id: UUID
    let executableBookmark: Data
    let name: String
    let executableURL: URL
    let prefixName: String
    let prefixURL: URL
    let arguments: [String]

    init(
        id: UUID = UUID(),
        executableBookmark: Data,
        name: String,
        executableURL: URL,
        prefixName: String,
        prefixURL: URL,
        arguments: [String] = []
    ) {
        self.id = id
        self.executableBookmark = executableBookmark
        self.name = name
        self.executableURL = executableURL
        self.prefixName = prefixName
        self.prefixURL = prefixURL
        self.arguments = arguments
    }
    
    func withExecutableURL(_ url: URL) -> WindowsApplication {
        WindowsApplication(
            id: id,
            executableBookmark: executableBookmark,
            name: name,
            executableURL: url,
            prefixName: prefixName,
            prefixURL: prefixURL,
            arguments: arguments
        )
    }
}
