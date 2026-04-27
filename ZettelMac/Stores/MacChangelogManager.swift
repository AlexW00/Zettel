//
//  MacChangelogManager.swift
//  ZettelMac
//
//  Manages changelog display for macOS app version updates.
//  Mirrors the iOS ChangelogManager pattern.
//

import Foundation
import ZettelKit

@MainActor
final class MacChangelogManager {
    static let shared = MacChangelogManager()

    private let lastSeenVersionKey = "macLastSeenAppVersion"
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"

    private init() {}

    /// Returns a changelog `Note` if the user is upgrading to a version that has one.
    /// Returns `nil` for first-time users or if the user has already seen this version.
    func pendingChangelogNote() -> Note? {
        guard let currentVersion = bundleVersion() else { return nil }

        // First-time users see the welcome note, not a changelog
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        guard hasLaunchedBefore else { return nil }

        let lastSeen = UserDefaults.standard.string(forKey: lastSeenVersionKey)

        // Already seen this version
        if lastSeen == currentVersion { return nil }

        // Find a matching changelog entry
        guard let entry = MacChangelogData.entries.first(where: { $0.version == currentVersion }) else {
            // No changelog for this version — record it as seen
            markSeen()
            return nil
        }

        return Note(title: entry.title, content: entry.content)
    }

    /// Mark the current version as seen so the changelog won't show again.
    func markSeen() {
        if let version = bundleVersion() {
            UserDefaults.standard.set(version, forKey: lastSeenVersionKey)
        }
    }

    private func bundleVersion() -> String? {
        // Use major.minor only (strip patch) to match ChangelogData keys like "1.3"
        guard let full = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        let parts = full.split(separator: ".")
        guard parts.count >= 2 else { return full }
        return "\(parts[0]).\(parts[1])"
    }
}
