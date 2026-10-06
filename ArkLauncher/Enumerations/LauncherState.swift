//
//  LauncherStates.swift
//  WineLauncher
//
//  Created by Nico Werner on 30.09.26.
//

import Foundation

enum LauncherState: Equatable {
    case ready
    case starting
    case running
    case ended(status: Int32)
    case killed

    var stateText: String {
        switch self {
        case .ready:
            return "Bereit"

        case .starting:
            return "Wird gestartet …"

        case .running:
            return "Läuft"

        case .ended(let status):
            return status == 0 ? "Beendet" : "Beendet (Code \(status))"

        case .killed:
            return "Beendet"
        }
    }
}
