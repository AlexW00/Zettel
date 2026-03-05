//
//  Tag.swift
//  ZettelKit
//
//  Tag model shared between iOS and macOS targets.
//

import Foundation

public struct Tag: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String          // Always lowercase for uniqueness
    public let displayName: String // Preserves original case for UI
    public let createdAt: Date
    public var usageCount: Int
    
    /// Computed property for backward compatibility
    public var name: String { id }
    
    public init(name: String) {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = sanitized
        self.id = sanitized.lowercased()
        self.createdAt = Date()
        self.usageCount = 1
    }
    
    /// Updates the usage count for this tag
    public mutating func incrementUsage() {
        usageCount += 1
    }
    
    /// Creates a tag from a hashtag string (removes the # prefix)
    public static func fromHashtag(_ hashtag: String) -> Tag? {
        let tagName = hashtag.hasPrefix("#") ? String(hashtag.dropFirst()) : hashtag
        
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard !tagName.isEmpty,
              tagName.rangeOfCharacter(from: validCharacterSet.inverted) == nil else {
            return nil
        }
        
        return Tag(name: tagName)
    }
    
    /// Returns the hashtag representation (#displayName)
    public var hashtag: String {
        return "#\(displayName)"
    }
}
