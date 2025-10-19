import Foundation

/// Manages the template used for generating default note titles.
final class DefaultTitleTemplateManager {
    static let shared = DefaultTitleTemplateManager()
    
    /// Storage key for persisting the custom template.
    private let storageKey = "defaultTitleTemplate"
    
    /// Built-in fallback template used when no custom template is set.
    let fallbackTemplate = "{{time}} – {{date}}"
    
    private init() {}
    
    /// Returns the saved custom template if present.
    func savedTemplate() -> String? {
        UserDefaults.standard.string(forKey: storageKey)
    }
    
    /// Persists a new template. Passing an empty or whitespace-only string clears the custom template.
    func saveTemplate(_ template: String) {
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey)
        } else {
            UserDefaults.standard.set(template, forKey: storageKey)
        }
    }
    
    /// Returns the template that should currently be used (custom or fallback).
    func currentTemplate() -> String {
        savedTemplate() ?? fallbackTemplate
    }
    
    /// Produces the default title for a given creation date using the active template.
    func generateTitle(for date: Date) -> String {
        let template = currentTemplate()
        let rendered = render(template: template, for: date)
        let trimmed = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallbackTitle(for: date)
        }
        return rendered
    }
    
    /// Returns fallback title matching the previous default behavior.
    func fallbackTitle(for date: Date) -> String {
        return fallbackFormatter.string(from: date)
    }
    
    /// Returns the available placeholder tokens and example outputs for them.
    func placeholderExamples(for date: Date = Date()) -> [(token: String, example: String)] {
        [
            ("{{time}}", timeFormatter.string(from: date)),
            ("{{date}}", dateFormatter.string(from: date)),
            ("{{shortDate}}", shortDateFormatter.string(from: date)),
            ("{{weekday}}", weekdayFormatter.string(from: date))
        ]
    }
    
    // MARK: - Rendering
    
    private func render(template: String, for date: Date) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{{time}}", with: timeFormatter.string(from: date))
        result = result.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: date))
        result = result.replacingOccurrences(of: "{{shortDate}}", with: shortDateFormatter.string(from: date))
        result = result.replacingOccurrences(of: "{{weekday}}", with: weekdayFormatter.string(from: date))
        return result
    }
    
    // MARK: - Formatters
    
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH-mm-ss"
        return formatter
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    private lazy var shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private lazy var weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    private lazy var fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH-mm-ss – d MMM yyyy"
        return formatter
    }()
}
