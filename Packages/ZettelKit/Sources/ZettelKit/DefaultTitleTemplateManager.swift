//
//  DefaultTitleTemplateManager.swift
//  ZettelKit
//
//  Manages the template used for generating default note titles.
//

import Foundation

/// Manages the template used for generating default note titles.
public final class DefaultTitleTemplateManager: Sendable {
    public static let shared = DefaultTitleTemplateManager()
    
    /// Storage key for persisting the custom template.
    private let storageKey = "defaultTitleTemplate"
    
    /// Built-in fallback template used when no custom template is set.
    public let fallbackTemplate = "{{shortDate}} – {{time}}"
    
    private init() {}
    
    /// Returns the saved custom template if present.
    public func savedTemplate() -> String? {
        UserDefaults.standard.string(forKey: storageKey)
    }
    
    /// Persists a new template.
    public func saveTemplate(_ template: String) {
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey)
        } else {
            UserDefaults.standard.set(template, forKey: storageKey)
        }
    }
    
    /// Returns the template that should currently be used (custom or fallback).
    public func currentTemplate() -> String {
        savedTemplate() ?? fallbackTemplate
    }
    
    /// Produces the default title for a given creation date using the active template.
    public func generateTitle(for date: Date) -> String {
        let template = currentTemplate()
        let rendered = render(template: template, for: date)
        let trimmed = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallbackTitle(for: date)
        }
        return rendered
    }
    
    /// Returns fallback title matching the previous default behavior.
    public func fallbackTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH-mm-ss – d MMM yyyy"
        return formatter.string(from: date)
    }
    
    /// Returns the available placeholder tokens and example outputs for them.
    public func placeholderExamples(for date: Date = Date()) -> [(token: String, example: String)] {
        [
            ("{{time}}", makeFormatter("HH-mm-ss").string(from: date)),
            ("{{date}}", makeFormatter("d MMM yyyy").string(from: date)),
            ("{{shortDate}}", makeFormatter("yyyy-MM-dd").string(from: date)),
            ("{{weekday}}", makeFormatter("EEEE").string(from: date))
        ]
    }
    
    // MARK: - Rendering
    
    private func render(template: String, for date: Date) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{{time}}", with: makeFormatter("HH-mm-ss").string(from: date))
        result = result.replacingOccurrences(of: "{{date}}", with: makeFormatter("d MMM yyyy").string(from: date))
        result = result.replacingOccurrences(of: "{{shortDate}}", with: makeFormatter("yyyy-MM-dd").string(from: date))
        result = result.replacingOccurrences(of: "{{weekday}}", with: makeFormatter("EEEE").string(from: date))
        return result
    }
    
    private func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}
