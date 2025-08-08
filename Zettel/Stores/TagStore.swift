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
    
    /// Compute tag index off the main thread and publish results on main.
    func updateTagsImmediately(from notes: [Note]) {
        // Capture light-weight copies for background work
        let lightweightNotes = notes.map { (title: $0.title, content: $0.content) }
        
        Task.detached {
            // Compute in background
            var tagCounts: [String: Int] = [:]
            var tagDisplayNames: [String: String] = [:]
            
            for note in lightweightNotes {
                // Single-pass extraction over title and content
                var noteText = note.title
                noteText.append(" ")
                noteText.append(note.content)
                
                // Use TagParser once per note text for both normalized and display names
                let (normalizedToDisplay, uniqueNormalized) = TagParser.extractNormalizedAndDisplay(from: noteText)
                
                for tagName in uniqueNormalized {
                    tagCounts[tagName, default: 0] += 1
                    if tagDisplayNames[tagName] == nil {
                        tagDisplayNames[tagName] = normalizedToDisplay[tagName] ?? tagName
                    }
                }
            }
            
            // Build Tag objects
            var newTagsByName: [String: Tag] = [:]
            for (normalizedName, count) in tagCounts {
                let displayName = tagDisplayNames[normalizedName] ?? normalizedName
                var tag = Tag(name: displayName)
                tag.usageCount = count
                newTagsByName[normalizedName] = tag
            }
            
            // Prepare immutable values to avoid capturing mutable vars across await
            let finalTagCounts = tagCounts
            let finalTagsByName = newTagsByName
            let finalSortedTags = Array(finalTagsByName.values).sorted { t1, t2 in
                if t1.usageCount != t2.usageCount { return t1.usageCount > t2.usageCount }
                return t1.displayName < t2.displayName
            }
            
            // Publish on main
            await MainActor.run {
                self.tagUsageCounts = finalTagCounts
                self.tagsByName = finalTagsByName
                self.sortedTags = finalSortedTags
            }
        }
    }
    
    /// Legacy method for backward compatibility
    func updateTags(from notes: [Note]) {
        updateTagsImmediately(from: notes)
    }
    
    /// Single-scan extractor that returns mapping normalized->display and the set of unique normalized tags
    private static func extractNormalizedAndDisplay(from text: String) -> ([String: String], Set<String>) {
        // moved to TagParser to avoid @MainActor isolation issues
        return TagParser.extractNormalizedAndDisplay(from: text)
    }
    
    /// Helper to find original case of a tag in text (no longer used)
    private func findOriginalTagCase(_ normalizedTag: String, in text: String) -> String? {
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
