//
//  TagParser.swift
//  Zettel
//
//  Created by GitHub Copilot on 04.07.25.
//
//  Utility class for parsing and manipulating hashtags in note content.
//

import Foundation

/**
 * Utility class for parsing hashtags from note content.
 * 
 * This class handles:
 * - Extracting hashtags from text using regex patterns
 * - Finding hashtags at specific cursor positions
 * - Replacing hashtags in text for autocomplete functionality
 * - Normalizing hashtag formatting
 */
class TagParser {
    /// Regex pattern to match hashtags: #followed by alphanumeric characters and underscores
    private static let hashtagPattern = #"#[a-zA-Z0-9_]+(?![a-zA-Z0-9_])"#
    private static let regex = try! NSRegularExpression(pattern: hashtagPattern, options: [])
    
    // Internal accessors for performance (used by TagStore)
    static var hashtagPatternInternal: String { hashtagPattern }
    static var regexInternal: NSRegularExpression { regex }
    
    /// Single-scan extractor returning mapping normalized->display and the set of unique normalized tags
    static func extractNormalizedAndDisplay(from text: String) -> ([String: String], Set<String>) {
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
    
    /**
     * Extracts all unique tags from the given text (normalized to lowercase).
     * 
     * - Parameter text: The text to extract tags from
     * - Returns: Set of unique tag names (without the # prefix)
     */
    static func extractTags(from text: String) -> Set<String> {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        var tags = Set<String>()
        for match in matches {
            if let range = Range(match.range, in: text) {
                let hashtag = String(text[range])
                if let tag = Tag.fromHashtag(hashtag) {
                    tags.insert(tag.id) // Use normalized ID instead of name
                }
            }
        }
        
        return tags
    }
    
    /// Extracts tags from both title and content of a note
    static func extractTags(from note: Note) -> Set<String> {
        var allTags = Set<String>()
        allTags.formUnion(extractTags(from: note.title))
        allTags.formUnion(extractTags(from: note.content))
        return allTags
    }
    
    /// Finds the position of hashtag being typed at cursor position
    static func findHashtagAtPosition(_ text: String, position: Int) -> (range: NSRange, partial: String)? {
        guard position <= text.count else { return nil }
        
        let textUpToCursor = String(text.prefix(position))
        
        // Find the last # before the cursor
        if let lastHashIndex = textUpToCursor.lastIndex(of: "#") {
            let hashPosition = textUpToCursor.distance(from: textUpToCursor.startIndex, to: lastHashIndex)
            
            // Check if there's any whitespace between # and cursor
            let textAfterHash = String(textUpToCursor.suffix(from: textUpToCursor.index(after: lastHashIndex)))
            if textAfterHash.contains(where: { $0.isWhitespace }) {
                return nil // Whitespace found, not a valid hashtag
            }
            
            // Get the partial tag text (everything after #)
            let partialTag = textAfterHash
            
            // Validate partial tag contains only valid characters
            let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
            if partialTag.rangeOfCharacter(from: validCharacterSet.inverted) != nil {
                return nil
            }
            
            let range = NSRange(location: hashPosition, length: partialTag.count + 1) // +1 for #
            return (range: range, partial: partialTag)
        }
        
        return nil
    }
    
    /// Replaces a hashtag at the given range with a completed tag
    static func replaceHashtag(in text: String, range: NSRange, with tagName: String) -> String {
        guard let textRange = Range(range, in: text) else { return text }
        
        let newHashtag = "#\(tagName)"
        var newText = text
        newText.replaceSubrange(textRange, with: newHashtag)
        
        return newText
    }
}
