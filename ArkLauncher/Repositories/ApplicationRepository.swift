//
//  ApplicationRepository.swift
//  WineLauncher
//
//  Created by Nico Werner on 02.10.26.
//

import Foundation

final class ApplicationRepository {

    private let prefixService: PrefixService
    private var applications: [WindowsApplication] = []
    private let bookmarkService: SecurityScopedBookmarkService
    private let applicationStore: ApplicationStore

    init(
        prefixService: PrefixService = PrefixService(),
        bookmarkService: SecurityScopedBookmarkService = SecurityScopedBookmarkService(),
        applicationStore: ApplicationStore = ApplicationStore()
    ) {
        self.prefixService = prefixService
        self.bookmarkService = bookmarkService
        self.applicationStore = applicationStore

        do {
            let storedApplications = try applicationStore.load()

            self.applications = storedApplications.compactMap { application in
                do {
                    let url = try bookmarkService.resolve(
                        bookmark: application.executableBookmark
                    )

                    print(
                        "WineLauncher: Bookmark aufgelöst: \(url.path)"
                    )

                    return application.withExecutableURL(url)

                } catch {
                    print(
                        "WineLauncher: Bookmark konnte nicht aufgelöst werden – \(error)"
                    )

                    return nil
                }
            }

            print(
                "WineLauncher: \(applications.count) Anwendungen geladen"
            )
        } catch {
            print(
                "WineLauncher: Anwendungen konnten nicht geladen werden – \(error)"
            )
        }
    }

    
    func application(
        name: String,
        executableURL: URL,
        prefixName: String
    ) async throws -> WindowsApplication {

        let bookmark = try bookmarkService.bookmark(
            for: executableURL
        )
        
        print(
                "WineLauncher: Bookmark erstellt: \(bookmark.count) Bytes"
            )

        let prefix = try await prefixService.getOrCreate(
            named: prefixName
        )

        return WindowsApplication(
            executableBookmark: bookmark,
            name: name,
            executableURL: executableURL,
            prefixName: prefixName,
            prefixURL: prefix
        )
    }
    
    func add(_ application: WindowsApplication) {
        guard !applications.contains(where: {
            $0.executableURL == application.executableURL
        }) else {
            return
        }

        applications.append(application)

        do {
            try applicationStore.save(applications)
        } catch {
            print(
                "WineLauncher: Anwendungen konnten nicht gespeichert werden – \(error)"
            )
        }

        print(
            "WineLauncher: Anwendung hinzugefügt: \(application.name)"
        )

        print(
            "WineLauncher: Anwendungen: \(applications.count)"
        )
    }
    
    func remove(_ application: WindowsApplication) {
        applications.removeAll {
            $0.id == application.id
        }

        do {
            try applicationStore.save(applications)
        } catch {
            print(
                "WineLauncher: Anwendungen konnten nach dem Entfernen nicht gespeichert werden – \(error)"
            )
        }

        print(
            "WineLauncher: Anwendung entfernt: \(application.name)"
        )

        print(
            "WineLauncher: Anwendungen: \(applications.count)"
        )
    }
    
    func all() -> [WindowsApplication] {
        applications
    }
}
