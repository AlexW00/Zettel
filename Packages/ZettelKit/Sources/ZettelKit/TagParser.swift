//
//  TagParser.swift
//  ZettelKit
//
//  Utility class for parsing and manipulating hashtags in note content.
//

import Foundation

/// Utility class for parsing hashtags from note content.
public final class TagParser: Sendable {
    /// Regex pattern to match hashtags: #followed by alphanumeric characters and underscores
    private static let hashtagPattern = #"#[a-zA-Z0-9_]+(?![a-zA-Z0-9_])"#
    // nonisolated(unsafe) because NSRegularExpression is inherently thread-safe for matching
    nonisolated(unsafe) private static let regex = try! NSRegularExpression(pattern: hashtagPattern, options: [])
    
    /// Internal accessors for performance (used by TagStore)
    public static var hashtagPatternInternal: String { hashtagPattern }
    public static var regexInternal: NSRegularExpression { regex }
    
    /// Single-scan extractor returning mapping normalized->display and the set of unique normalized tags
    public static func extractNormalizedAndDisplay(from text: String) -> ([String: String], Set<String>) {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        var normalizedToDisplay: [String: String] = [:]
        var unique: Set<String> = []
        for match in matches {
            if let r = Range(match.range, in: text) {
                let hashtag = String(text[r])
                if let tag = Tag.fromHashtag(hashtag) {
                    unique.insert(tag.id)
                    if normalizedToDisplay[tag.id] == nil {
                        normalizedToDisplay[tag.id] = tag.displayName
                    }
                }
            }
        }
        return (normalizedToDisplay, unique)
    }
    
    /// Extracts all unique tags from the given text (normalized to lowercase).
    public static func extractTags(from text: String) -> Set<String> {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        var tags = Set<String>()
        for match in matches {
            if let range = Range(match.range, in: text) {
                let hashtag = String(text[range])
                if let tag = Tag.fromHashtag(hashtag) {
                    tags.insert(tag.id)
                }
            }
        }
        
        return tags
    }
    
    /// Extracts tags from both title and content of a note
    public static func extractTags(from note: Note) -> Set<String> {
        var allTags = Set<String>()
        allTags.formUnion(extractTags(from: note.title))
        allTags.formUnion(extractTags(from: note.content))
        return allTags
    }
    
    /// Finds the position of hashtag being typed at cursor position
    public static func findHashtagAtPosition(_ text: String, position: Int) -> (range: NSRange, partial: String)? {
        guard position <= text.count else { return nil }
        
        let textUpToCursor = String(text.prefix(position))
        
        if let lastHashIndex = textUpToCursor.lastIndex(of: "#") {
            let hashPosition = textUpToCursor.distance(from: textUpToCursor.startIndex, to: lastHashIndex)
            
            let textAfterHash = String(textUpToCursor.suffix(from: textUpToCursor.index(after: lastHashIndex)))
            if textAfterHash.contains(where: { $0.isWhitespace }) {
                return nil
            }
            
            let partialTag = textAfterHash
            
            let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
            if partialTag.rangeOfCharacter(from: validCharacterSet.inverted) != nil {
                return nil
            }
            
            let range = NSRange(location: hashPosition, length: partialTag.count + 1)
            return (range: range, partial: partialTag)
        }
        
        return nil
    }
    
    /// Replaces a hashtag at the given range with a completed tag
    public static func replaceHashtag(in text: String, range: NSRange, with tagName: String) -> String {
        guard let textRange = Range(range, in: text) else { return text }
        
        let newHashtag = "#\(tagName)"
        var newText = text
        newText.replaceSubrange(textRange, with: newHashtag)
        
        return newText
    }
}
