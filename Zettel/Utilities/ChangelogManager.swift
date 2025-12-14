//
//  ChangelogManager.swift
//  Zettel
//
//  Manages changelog display for app version updates.
//  Parses markdown changelog files and tracks which versions users have seen.
//

import Foundation

/// Represents a parsed changelog entry
struct ChangelogEntry: Identifiable {
    let id = UUID()
    let version: AppVersion
    let title: String
    let content: String
    
    /// The full title including version (e.g., "v2.2 - New Features")
    var fullTitle: String {
        return title
    }
}

/// Represents an app version with major and minor components
struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    let major: Int
    let minor: Int
    
    var description: String {
        return "\(major).\(minor)"
    }
    
    var displayString: String {
        return "v\(major).\(minor)"
    }
    
    init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
    
    /// Parses a version string like "2.2" or "v2.2" into an AppVersion
    init?(from string: String) {
        // Remove 'v' prefix if present
        var versionString = string.trimmingCharacters(in: .whitespaces)
        if versionString.lowercased().hasPrefix("v") {
            versionString = String(versionString.dropFirst())
        }
        
        // Split by dot and parse major.minor (ignore patch if present)
        let components = versionString.split(separator: ".")
        guard components.count >= 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return nil
        }
        
        self.major = major
        self.minor = minor
    }
    
    /// Creates an AppVersion from the current app's bundle version
    static var current: AppVersion? {
        guard let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return AppVersion(from: versionString)
    }
    
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }
}

/// Manages changelog entries and tracks which versions users have seen
@MainActor
class ChangelogManager: ObservableObject {
    static let shared = ChangelogManager()
    
    /// Key for storing the last seen app version in UserDefaults
    private let lastSeenVersionKey = "lastSeenAppVersion"
    
    /// All available changelog entries, sorted by version (newest first)
    @Published private(set) var changelogEntries: [ChangelogEntry] = []
    
    /// The changelog entry to display (if any)
    @Published private(set) var pendingChangelog: ChangelogEntry?
    
    private init() {
        loadChangelogEntries()
    }
    
    /// Loads changelog entries from static data
    private func loadChangelogEntries() {
        var entries: [ChangelogEntry] = []
        
        #if DEBUG
        print("[Changelog] Loading changelog entries from static data...")
        #endif
        
        // Load from static Swift data (most reliable)
        for data in ChangelogData.entries {
            if let version = AppVersion(from: data.version) {
                let entry = ChangelogEntry(
                    version: version,
                    title: data.title,
                    content: data.content
                )
                entries.append(entry)
                #if DEBUG
                print("[Changelog] Loaded: \(entry.version.displayString) - \(entry.title)")
                #endif
            }
        }
        
        #if DEBUG
        print("[Changelog] Total entries loaded: \(entries.count)")
        #endif
        
        // Sort by version (newest first)
        changelogEntries = entries.sorted { $0.version > $1.version }
    }
    
    /// Checks if there's a new changelog to display and sets pendingChangelog
    func checkForNewChangelog() {
        #if DEBUG
        print("[Changelog] Checking for new changelog...")
        print("[Changelog] App version: \(AppVersion.current?.displayString ?? "nil")")
        print("[Changelog] Available changelogs: \(changelogEntries.map { $0.version.displayString })")
        #endif
        
        guard let currentVersion = AppVersion.current else {
            #if DEBUG
            print("[Changelog] ERROR: Could not get current app version from bundle")
            #endif
            return
        }
        
        let lastSeenVersion = getLastSeenVersion()
        #if DEBUG
        print("[Changelog] Last seen version: \(lastSeenVersion?.displayString ?? "nil (first launch)")")
        #endif
        
        // Find the changelog entry for the current app version
        guard let currentChangelog = changelogEntries.first(where: { $0.version == currentVersion }) else {
            #if DEBUG
            print("[Changelog] No changelog found for current version \(currentVersion.displayString)")
            #endif
            // No changelog for current version, update last seen anyway
            setLastSeenVersion(currentVersion)
            return
        }
        
        #if DEBUG
        print("[Changelog] Found changelog for current version: \(currentChangelog.title)")
        #endif
        
        // Show changelog only if user has seen a previous version (not first-time users)
        // First-time users (lastSeenVersion == nil) should see the welcome note instead
        if let lastSeen = lastSeenVersion, lastSeen < currentVersion {
            #if DEBUG
            print("[Changelog] Showing changelog (upgrade from \(lastSeen.displayString) to \(currentVersion.displayString))")
            #endif
            pendingChangelog = currentChangelog
        } else if lastSeenVersion == nil {
            #if DEBUG
            print("[Changelog] First-time user, not showing changelog")
            #endif
            // First-time user - just set the current version as seen, don't show changelog
            setLastSeenVersion(currentVersion)
        } else {
            #if DEBUG
            print("[Changelog] Already seen this version, not showing changelog")
            #endif
        }
    }
    
    /// Called when user dismisses the changelog
    func dismissChangelog() {
        guard let currentVersion = AppVersion.current else {
            return
        }
        setLastSeenVersion(currentVersion)
        pendingChangelog = nil
    }
    
    /// Gets the last seen app version from UserDefaults
    private func getLastSeenVersion() -> AppVersion? {
        guard let versionString = UserDefaults.standard.string(forKey: lastSeenVersionKey) else {
            return nil
        }
        return AppVersion(from: versionString)
    }
    
    /// Saves the last seen app version to UserDefaults
    private func setLastSeenVersion(_ version: AppVersion) {
        UserDefaults.standard.set(version.description, forKey: lastSeenVersionKey)
    }
    
    /// Returns the changelog entry for the current app version (if available)
    func getChangelogForCurrentVersion() -> ChangelogEntry? {
        guard let currentVersion = AppVersion.current else {
            return nil
        }
        return changelogEntries.first(where: { $0.version == currentVersion })
    }
    
    /// For debugging: clears the last seen version to force changelog display
    func resetLastSeenVersion() {
        UserDefaults.standard.removeObject(forKey: lastSeenVersionKey)
        pendingChangelog = nil
        checkForNewChangelog()
    }
    
    /// For debugging: sets a specific last seen version
    func setDebugLastSeenVersion(_ version: AppVersion) {
        setLastSeenVersion(version)
    }
}
