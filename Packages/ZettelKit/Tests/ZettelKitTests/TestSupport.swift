import Foundation

struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}

func makeDate(
    year: Int = 2026,
    month: Int = 3,
    day: Int = 9,
    hour: Int = 12,
    minute: Int = 34,
    second: Int = 56
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return components.date!
}

func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "ZettelKitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
