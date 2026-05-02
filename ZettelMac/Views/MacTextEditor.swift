//
//  MacTextEditor.swift
//  ZettelMac
//
//  NSViewRepresentable wrapping NSTextView for the note body.
//  Provides hashtag highlighting and proper macOS text editing.
//

import SwiftUI
import AppKit
import ZettelKit

// MARK: - Editor handle

/// Lightweight class that holds a weak reference to the underlying NSScrollView.
/// Use `snapshot()` to capture the current rendered content as an NSImage,
/// e.g. before applying a Metal layer effect that can't display NSViewRepresentable.
@MainActor
final class MacTextEditorHandle {
    weak var scrollView: NSScrollView?

    /// Returns a bitmap snapshot of the scroll view's current visual state,
    /// or `nil` if the view isn't ready.
    func snapshot() -> NSImage? {
        guard let view = scrollView, !view.bounds.isEmpty else { return nil }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// Restores keyboard focus to the underlying NSTextView.
    func focusEditor() {
        guard let textView = scrollView?.documentView else { return }
        textView.window?.makeFirstResponder(textView)
    }
}

private struct BulletInfo {
    enum BulletType {
        case dash
        case asterisk
        case numbered(Int)
    }

    let type: BulletType
    let prefix: String
}

struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onInteraction: (() -> Void)?
    /// All tag display names known across notes — used for autocomplete suggestions.
    var allTags: [String] = []
    /// Optional handle whose `scrollView` property is kept up-to-date so
    /// callers can snapshot the view before running Metal layer effects.
    var handle: MacTextEditorHandle? = nil

    /// Font size driven by the Settings slider. Mirrors the iOS app's
    /// `themeStore.contentFontSize` so changes apply live without a relaunch.
    @AppStorage(EditorFontPreference.key) private var editorFontSizeRaw: Double = EditorFontPreference.defaultSize

    private var resolvedEditorFontSize: CGFloat {
        EditorFontPreference.resolve(editorFontSizeRaw)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = false
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = InteractionTextView(frame: .zero, textContainer: textContainer)
        textView.onInteraction = onInteraction

        let scrollView = NSScrollView()
        scrollView.documentView = textView

        // Configure text view
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Appearance
        textView.font = .monospacedSystemFont(ofSize: resolvedEditorFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.insertionPointColor = .labelColor

        // Layout
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        // Allow the text view to grow to any height so the scroll view's
        // document view always matches the full content height.
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)

        // Scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        // Ensure the scroll view clips its content at the AppKit layer level.
        // SwiftUI's .clipShape() does not reliably mask the NSTextView's own
        // CALayer rendering, which causes ghost-text artifacts at the card edges.
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.cornerRadius = 18
        // Prevent macOS from automatically adding a top content inset for the
        // window toolbar. Without this, the document view is shifted down and
        // the last lines of text fall below the clip view, making them
        // unreachable by scrolling.
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)

        // Delegate
        textView.delegate = context.coordinator

        // Set initial text
        textView.string = text
        context.coordinator.applyHashtagHighlighting(to: textView)

        handle?.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        handle?.scrollView = scrollView
        guard let textView = scrollView.documentView as? NSTextView else { return }
        (textView as? InteractionTextView)?.onInteraction = onInteraction
        context.coordinator.allTags = allTags

        let targetFontSize = resolvedEditorFontSize
        context.coordinator.editorFontSize = targetFontSize
        if textView.font?.pointSize != targetFontSize {
            textView.font = .monospacedSystemFont(ofSize: targetFontSize, weight: .regular)
            context.coordinator.applyHashtagHighlighting(to: textView)
            (textView as? InteractionTextView)?.refreshRendering()
        }

        // Only update if the text actually differs (avoid cursor jumping).
        // Never replace text while the IME has uncommitted (marked) input —
        // doing so destroys the composition session and drops characters.
        if textView.string != text && !textView.hasMarkedText() {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHashtagHighlighting(to: textView)
            (textView as? InteractionTextView)?.refreshRendering()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, allTags: allTags, editorFontSize: resolvedEditorFontSize)
    }

    // MARK: - Coordinator

    final class InteractionTextView: NSTextView {
        var onInteraction: (() -> Void)?

        override func didChangeText() {
            super.didChangeText()
            guard !hasMarkedText() else { return }
            refreshRendering()
        }

        override func insertNewline(_ sender: Any?) {
            handleNewlineForAutoBullet()
        }

        override func deleteToBeginningOfLine(_ sender: Any?) {
            let sel = selectedRange()
            let str = string as NSString
            let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
            let charsBeforeCursor = sel.location - lineRange.location
            if charsBeforeCursor > 0 {
                // Delete from start of line up to cursor
                insertText("", replacementRange: NSRange(location: lineRange.location, length: charsBeforeCursor))
            } else if lineRange.location > 0 {
                // Already at start of line — delete the preceding newline to merge with previous line
                insertText("", replacementRange: NSRange(location: lineRange.location - 1, length: 1))
            }
        }

        override func becomeFirstResponder() -> Bool {
            let became = super.becomeFirstResponder()
            if became {
                onInteraction?()
            }
            return became
        }

        override func mouseDown(with event: NSEvent) {
            onInteraction?()
            super.mouseDown(with: event)
        }

        private func handleNewlineForAutoBullet() {
            let cursorPosition = selectedRange().location
            let textBeforeCursor = String(string.prefix(cursorPosition))

            // Find the current line (text after last newline)
            let lines = textBeforeCursor.components(separatedBy: "\n")
            let currentLine = lines.last ?? ""

            if let bulletInfo = detectBulletPattern(in: currentLine) {
                if isEmptyBulletLine(currentLine, bulletInfo: bulletInfo) {
                    // User wants a simple newline, not removal.
                    super.insertNewline(nil)
                } else {
                    // Insert next bullet point
                    insertNextBullet(bulletInfo: bulletInfo)
                }
            } else {
                // Normal newline behavior
                super.insertNewline(nil)
            }
        }

        private func detectBulletPattern(in line: String) -> BulletInfo? {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for dash bullet (- )
            if trimmedLine.hasPrefix("- ") {
                return BulletInfo(type: .dash, prefix: "- ")
            }

            // Check for asterisk bullet (* )
            if trimmedLine.hasPrefix("* ") {
                return BulletInfo(type: .asterisk, prefix: "* ")
            }

            // Check for numbered list (1. 2. 3. etc.)
            let numberedPattern = #"^(\d+)\.\s"#
            if let regex = try? NSRegularExpression(pattern: numberedPattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(location: 0, length: trimmedLine.count)) {
                let numberRange = match.range(at: 1)
                let numberString = String(trimmedLine[Range(numberRange, in: trimmedLine)!])
                if let number = Int(numberString) {
                    return BulletInfo(type: .numbered(number), prefix: "\(number). ")
                }
            }

            return nil
        }

        private func isEmptyBulletLine(_ line: String, bulletInfo: BulletInfo) -> Bool {
            let contentAfterBullet = line.dropFirst(bulletInfo.prefix.count).trimmingCharacters(in: .whitespaces)
            return contentAfterBullet.isEmpty
        }

        private func insertNextBullet(bulletInfo: BulletInfo) {
            let nextBulletPrefix: String

            switch bulletInfo.type {
            case .dash:
                nextBulletPrefix = "\n- "
            case .asterisk:
                nextBulletPrefix = "\n* "
            case .numbered(let currentNumber):
                nextBulletPrefix = "\n\(currentNumber + 1). "
            }

            // Insert the newline and next bullet
            super.insertText(nextBulletPrefix, replacementRange: selectedRange())
        }

        func refreshRendering() {
            guard let layoutManager = layoutManager,
                  let textContainer = textContainer else {
                needsDisplay = true
                enclosingScrollView?.contentView.needsDisplay = true
                return
            }

            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            layoutManager.ensureLayout(for: textContainer)

            needsDisplay = true
            enclosingScrollView?.contentView.needsDisplay = true
            enclosingScrollView?.reflectScrolledClipView(enclosingScrollView?.contentView ?? NSClipView())
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var allTags: [String]
        var editorFontSize: CGFloat
        private var isUpdating = false

        // MARK: Autocomplete
        private let autocomplete = TagAutocompleteController()
        /// NSRange covering `#partialTag` currently being typed (in the text view's string).
        private var currentTagRange: NSRange?

        init(text: Binding<String>, allTags: [String], editorFontSize: CGFloat) {
            self.text = text
            self.allTags = allTags
            self.editorFontSize = editorFontSize
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            guard !textView.hasMarkedText() else { return }
            isUpdating = true
            text.wrappedValue = textView.string
            applyHashtagHighlighting(to: textView)
            isUpdating = false
            updateAutocomplete(in: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard autocomplete.isVisible else { return }
            let cursor = textView.selectedRange().location
            if TagParser.findHashtagAtPosition(textView.string, position: cursor) == nil {
                autocomplete.hide()
                currentTagRange = nil
            }
        }

        // MARK: Command interception (Tab, Return, Escape)

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard autocomplete.isVisible else { return false }

            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                autocomplete.selectNext()
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                autocomplete.selectPrevious()
                return true
            case #selector(NSResponder.moveDown(_:)):
                autocomplete.selectNext()
                return true
            case #selector(NSResponder.moveUp(_:)):
                autocomplete.selectPrevious()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                completeSelectedSuggestion(in: textView)
                return true
            case #selector(NSResponder.cancelOperation(_:)): // Escape
                autocomplete.hide()
                currentTagRange = nil
                return true
            default:
                return false
            }
        }

        // MARK: Autocomplete helpers

        private func updateAutocomplete(in textView: NSTextView) {
            let cursor = textView.selectedRange().location
            let text = textView.string

            guard let result = TagParser.findHashtagAtPosition(text, position: cursor) else {
                autocomplete.hide()
                currentTagRange = nil
                return
            }

            currentTagRange = result.range
            let prefix = result.partial.lowercased()

            // Match all known tags by prefix; partial empty = just typed '#', show all
            let suggestions: [String] = allTags
                .filter { prefix.isEmpty || $0.lowercased().hasPrefix(prefix) }
                .sorted { $0.lowercased() < $1.lowercased() }
                .prefix(20)
                .map { $0 }

            guard !suggestions.isEmpty else {
                autocomplete.hide()
                return
            }

            // Anchor below the end of the partial tag in screen coordinates
            let anchorLoc = result.range.location + result.range.length
            let anchorRange = NSRange(location: anchorLoc, length: 0)
            var actualRange = NSRange()
            let screenRect = textView.firstRect(forCharacterRange: anchorRange, actualRange: &actualRange)

            if autocomplete.isVisible {
                autocomplete.update(suggestions: suggestions)
            } else {
                autocomplete.show(suggestions: suggestions, near: screenRect) { [weak self, weak textView] tag in
                    guard let self, let textView else { return }
                    self.completeTag(tag, in: textView)
                }
            }
        }

        private func completeSelectedSuggestion(in textView: NSTextView) {
            guard let tag = autocomplete.selectedSuggestion else { return }
            completeTag(tag, in: textView)
        }

        private func completeTag(_ tag: String, in textView: NSTextView) {
            guard let tagRange = currentTagRange else { return }
            let fullTag = "#\(tag)"
            textView.insertText(fullTag, replacementRange: tagRange)
            autocomplete.hide()
            currentTagRange = nil
        }

        @MainActor
        func applyHashtagHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage,
                  !textView.hasMarkedText() else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string
            let fontSize = editorFontSize

            // Reset to default style
            let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let defaultColor = NSColor.labelColor
            textStorage.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
            textStorage.addAttribute(.font, value: defaultFont, range: fullRange)

            // Highlight hashtags
            let regex = TagParser.regexInternal
            let matches = regex.matches(in: text, options: [], range: fullRange)

            let hashtagColor = NSColor.controlAccentColor
            let hashtagFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)

            for match in matches {
                textStorage.addAttribute(.foregroundColor, value: hashtagColor, range: match.range)
                textStorage.addAttribute(.font, value: hashtagFont, range: match.range)
            }
        }
    }
}

// MARK: - Editor Font Preference

/// Shared accessor for the editor's body font size preference. The range and
/// default match iOS's `LayoutConstants.FontSize.contentMinSize/Max/Default`
/// so the slider, settings clamp, and editor stay in lockstep across platforms.
enum EditorFontPreference {
    static let key = "editorFontSize"
    static let minSize: Double = 12
    static let maxSize: Double = 24
    static let defaultSize: Double = 16

    /// Clamp a stored value into the supported range, mapping the legacy
    /// "unset = 0" sentinel to the default.
    static func resolve(_ raw: Double) -> CGFloat {
        let normalized = raw == 0 ? defaultSize : raw
        return CGFloat(min(max(normalized, minSize), maxSize))
    }

    /// The current preference clamped into the supported range, suitable
    /// for seeding a `Slider` whose bounds are `minSize...maxSize`.
    static var savedValue: Double {
        let raw = UserDefaults.standard.double(forKey: key)
        let normalized = raw == 0 ? defaultSize : raw
        return min(max(normalized, minSize), maxSize)
    }
}
