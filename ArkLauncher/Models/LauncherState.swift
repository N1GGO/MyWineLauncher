enum LauncherState {
    case ready
    case starting
    case running
    case ended
    case killed

    var stateText: String {
        switch self {
        case .ready: return "Bereit"
        case .starting: return "Wird gestartet..."
        case .running: return "Läuft"
        case .ended: return "Prozess ist geendet"
        case .killed: return "Nutzer hat den Prozess beendet"
        }
    }
}
