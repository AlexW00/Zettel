import Foundation

func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "ZettelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
