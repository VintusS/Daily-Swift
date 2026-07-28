import Foundation

enum AppFirstRunState: Equatable, Sendable {
    case idle
    case saving
}

enum AppSessionMode: Equatable, Sendable {
    case persistent
    case temporary
}

enum AppShellFailure: Error, Equatable, Sendable {
    case storeUnavailable
    case restorationCorrupt
    case unsupportedSnapshotVersion
    case saveFailed
}

enum AppRootState: Equatable, Sendable {
    case launching
    case restoring
    case firstRun(AppFirstRunState)
    case ready(AppSessionMode)
    case recoverableStorageFailure(AppShellFailure)
}
