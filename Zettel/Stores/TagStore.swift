//
//  TagStore.swift
//  Zettel
//
//  Created by GitHub Copilot on 04.07.25.
//

import Foundation
import SwiftUI

@MainActor
class TagStore: ObservableObject {
    @Published private(set) var tagsByName: [String: Tag] = [:]
    @Published private(set) var sortedTags: [Tag] = []
    @Published private(set) var tagUsageCounts: [String: Int] = [:]
    
    // Debouncing support
    private var updateTimer: Timer?
    private let updateDelay: TimeInterval = CacheConstants.tagUpdateDelay
    
    // Application lifecycle support
    private var pendingNotes: [Note] = []
    
    // Backward compatibility
    var allTags: [Tag] {
        return sortedTags
    }
    
    init() {
        // Subscribe to application lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func applicationWillTerminate() {
        // Force immediate update when app is terminating
        flushPendingUpdates()
    }
    
    @objc private func applicationDidEnterBackground() {
        // Force immediate update when app enters background
        flushPendingUpdates()
    }
    
    /// Flushes any pending tag updates immediately
    private func flushPendingUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        if !pendingNotes.isEmpty {
            updateTagsImmediately(from: pendingNotes)
            pendingNotes.removeAll()
        }
    }
    
    /// Schedules a debounced tag update
    func scheduleTagUpdate(from notes: [Note]) {
        // Store pending notes for potential flush
        pendingNotes = notes
        
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateTagsImmediately(from: notes)
                self.pendingNotes.removeAll()
            }
        }
    }
    
    /// Updates the tag store with tags from all notes (immediate, no debouncing)
    func updateTagsImmediately(from notes: [Note]) {
        var tagCounts: [String: Int] = [:]
        var tagDisplayNames: [String: String] = [:]
        
        // Count tag usage across all notes
        for note in notes {
            let noteTags = note.extractedTags
            for tagName in noteTags {
                tagCounts[tagName, default: 0] += 1
                // Keep track of display name (preserve case from first occurrence)
                if tagDisplayNames[tagName] == nil {
                    // Find the original hashtag in the note to preserve case
                    let allText = note.title + " " + note.content
                    if let originalTag = findOriginalTagCase(tagName, in: allText) {
                        tagDisplayNames[tagName] = originalTag
                    } else {
                        tagDisplayNames[tagName] = tagName
                    }
                }
            }
        }
        
        // Update published properties
        self.tagUsageCounts = tagCounts
        
        // Create Tag objects with usage counts and display names
        var newTagsByName: [String: Tag] = [:]
        for (normalizedName, count) in tagCounts {
            let displayName = tagDisplayNames[normalizedName] ?? normalizedName
            var tag = Tag(name: displayName)
            tag.usageCount = count
            newTagsByName[normalizedName] = tag
        }
        
        self.tagsByName = newTagsByName
        
        // Create sorted array for UI
        self.sortedTags = Array(newTagsByName.values).sorted { tag1, tag2 in
            // Sort by usage count (descending), then by display name (ascending)
            if tag1.usageCount != tag2.usageCount {
                return tag1.usageCount > tag2.usageCount
            }
            return tag1.displayName < tag2.displayName
        }
    }
    
    /// Legacy method for backward compatibility
    func updateTags(from notes: [Note]) {
        updateTagsImmediately(from: notes)
    }
    
    /// Helper to find original case of a tag in text
    private func findOriginalTagCase(_ normalizedTag: String, in text: String) -> String? {
        let pattern = "#([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: text) {
                let foundTag = String(text[tagRange])
                if foundTag.lowercased() == normalizedTag {
                    return foundTag
                }
            }
        }
        return nil
    }
    
    /// Gets tags that match a partial string (for autocomplete) - optimized O(1) lookup
    /// Excludes a specific tag that's currently being edited
    func getMatchingTags(for partial: String, excludingCurrentTag currentTagRange: NSRange? = nil, fromText text: String? = nil) -> [Tag] {
        let lowercasePartial = partial.lowercased()
        
        if lowercasePartial.isEmpty {
            // Return most popular tags when no filter
            return Array(sortedTags.prefix(10))
        }
        
        // Determine the tag being currently edited to exclude it
        var tagToExclude: String? = nil
        if let range = currentTagRange, let text = text,
           let textRange = Range(range, in: text) {
            let currentTagText = String(text[textRange])
            if currentTagText.hasPrefix("#") {
                let tagName = String(currentTagText.dropFirst()).lowercased()
                tagToExclude = tagName
            }
        }
        
        return sortedTags.filter { tag in
            let lowercaseTagName = tag.id.lowercased()
            return lowercaseTagName.hasPrefix(lowercasePartial) && 
                   lowercaseTagName != tagToExclude
        }
    }
    
    /// O(1) tag lookup by name
    func getTag(byName name: String) -> Tag? {
        return tagsByName[name.lowercased()]
    }
    
    /// Gets the most popular tags (for filtering UI)
    func getMostPopularTags(limit: Int = 5) -> [Tag] {
        return Array(sortedTags.prefix(limit))
    }
    
    /// Gets all notes that contain a specific tag
    func getNotesWithTag(_ tagName: String, from notes: [Note]) -> [Note] {
        return notes.filter { note in
            note.hasTag(tagName)
        }
    }
    
    /// Gets notes that contain any of the specified tags
    func getNotesWithAnyTag(_ tagNames: Set<String>, from notes: [Note]) -> [Note] {
        return notes.filter { note in
            !note.extractedTags.isDisjoint(with: tagNames)
        }
    }
    
    /// Gets notes that contain all of the specified tags
    func getNotesWithAllTags(_ tagNames: Set<String>, from notes: [Note]) -> [Note] {
        return notes.filter { note in
            tagNames.isSubset(of: note.extractedTags)
        }
    }
    
    /// Checks if a tag exists in the store
    func tagExists(_ tagName: String) -> Bool {
        return tagUsageCounts[tagName.lowercased()] != nil
    }
    
    /// Gets the usage count for a specific tag
    func getUsageCount(for tagName: String) -> Int {
        return tagUsageCounts[tagName.lowercased()] ?? 0
    }
}
