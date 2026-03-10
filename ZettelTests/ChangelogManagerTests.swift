import Foundation
import Testing
@testable import Zettel

@MainActor
struct ChangelogManagerTests {
    @Test
    func appVersionParsesAndComparesVersions() {
        #expect(AppVersion(from: "v3.1") == AppVersion(major: 3, minor: 1))
        #expect(AppVersion(from: "3.10")! > AppVersion(from: "3.2")!)
        #expect(AppVersion(from: "invalid") == nil)
    }

    @Test
    func changelogShowsForUpgradeWhenUserHasLaunchedBefore() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "hasLaunchedBefore")
        defaults.set("2.2", forKey: "lastSeenAppVersion")

        let manager = ChangelogManager(
            userDefaults: defaults,
            currentVersionProvider: { AppVersion(major: 3, minor: 0) },
            changelogDataProvider: {
                [(version: "3.0", title: "v3.0", content: "Release notes")]
            }
        )

        manager.checkForNewChangelog()

        #expect(manager.pendingChangelog?.version == AppVersion(major: 3, minor: 0))
    }

    @Test
    func dismissingChangelogPersistsCurrentVersion() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "hasLaunchedBefore")
        defaults.set("2.2", forKey: "lastSeenAppVersion")

        let manager = ChangelogManager(
            userDefaults: defaults,
            currentVersionProvider: { AppVersion(major: 3, minor: 0) },
            changelogDataProvider: {
                [(version: "3.0", title: "v3.0", content: "Release notes")]
            }
        )

        manager.checkForNewChangelog()
        manager.dismissChangelog()

        #expect(manager.pendingChangelog == nil)
        #expect(defaults.string(forKey: "lastSeenAppVersion") == "3.0")
    }

    @Test
    func firstLaunchSuppressesChangelogAndMarksVersionSeen() {
        let defaults = makeIsolatedDefaults()

        let manager = ChangelogManager(
            userDefaults: defaults,
            currentVersionProvider: { AppVersion(major: 3, minor: 0) },
            changelogDataProvider: {
                [(version: "3.0", title: "v3.0", content: "Release notes")]
            }
        )

        manager.checkForNewChangelog()

        #expect(manager.pendingChangelog == nil)
        #expect(defaults.string(forKey: "lastSeenAppVersion") == "3.0")
    }

    @Test
    func missingCurrentVersionChangelogStillAdvancesLastSeenVersion() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "hasLaunchedBefore")
        defaults.set("2.2", forKey: "lastSeenAppVersion")

        let manager = ChangelogManager(
            userDefaults: defaults,
            currentVersionProvider: { AppVersion(major: 4, minor: 0) },
            changelogDataProvider: {
                [(version: "3.0", title: "v3.0", content: "Release notes")]
            }
        )

        manager.checkForNewChangelog()

        #expect(manager.pendingChangelog == nil)
        #expect(defaults.string(forKey: "lastSeenAppVersion") == "4.0")
    }
}
