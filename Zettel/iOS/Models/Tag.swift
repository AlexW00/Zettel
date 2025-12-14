//
//  Tag.swift
//  Zettel
//
//  Created by GitHub Copilot on 04.07.25.
//

import Foundation

struct Tag: Identifiable, Codable, Equatable, Hashable {
    let id: String          // Always lowercase for uniqueness
    let displayName: String // Preserves original case for UI
    let createdAt: Date
    var usageCount: Int
    
    // Computed property for backward compatibility
    var name: String { id }
    
    init(name: String) {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = sanitized
        self.id = sanitized.lowercased()
        self.createdAt = Date()
        self.usageCount = 1
    }
    
    /// Updates the usage count for this tag
    mutating func incrementUsage() {
        usageCount += 1
    }
    
    /// Creates a tag from a hashtag string (removes the # prefix)
    static func fromHashtag(_ hashtag: String) -> Tag? {
        let tagName = hashtag.hasPrefix("#") ? String(hashtag.dropFirst()) : hashtag
        
        // Validate tag name (alphanumeric + underscore only)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard !tagName.isEmpty,
              tagName.rangeOfCharacter(from: validCharacterSet.inverted) == nil else {
            return nil
        }
        
        return Tag(name: tagName)
    }
    
    /// Returns the hashtag representation (#displayName)
    var hashtag: String {
        return "#\(displayName)"
    }
}
