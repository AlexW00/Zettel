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

struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onInteraction: (() -> Void)?

    private static var resolvedEditorFontSize: CGFloat {
        let value = UserDefaults.standard.double(forKey: "editorFontSize")
        let normalized = value == 0 ? 15 : value
        return CGFloat(min(max(normalized, 12), 28))
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
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
        textView.font = .systemFont(ofSize: Self.resolvedEditorFontSize, weight: .regular)
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

        // Scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        // Delegate
        textView.delegate = context.coordinator

        // Set initial text
        textView.string = text
        context.coordinator.applyHashtagHighlighting(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        (textView as? InteractionTextView)?.onInteraction = onInteraction

        let targetFontSize = Self.resolvedEditorFontSize
        if textView.font?.pointSize != targetFontSize {
            textView.font = .systemFont(ofSize: targetFontSize, weight: .regular)
            context.coordinator.applyHashtagHighlighting(to: textView)
        }

        // Only update if the text actually differs (avoid cursor jumping)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHashtagHighlighting(to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    // MARK: - Coordinator

    final class InteractionTextView: NSTextView {
        var onInteraction: (() -> Void)?

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
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        private var isUpdating = false

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            text.wrappedValue = textView.string
            applyHashtagHighlighting(to: textView)
            isUpdating = false
        }

        @MainActor
        func applyHashtagHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string
            let fontSize = MacTextEditor.resolvedEditorFontSize

            // Reset to default style
            let defaultFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            let defaultColor = NSColor.labelColor
            textStorage.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
            textStorage.addAttribute(.font, value: defaultFont, range: fullRange)

            // Highlight hashtags
            let regex = TagParser.regexInternal
            let matches = regex.matches(in: text, options: [], range: fullRange)

            let hashtagColor = NSColor.systemBlue
            let hashtagFont = NSFont.systemFont(ofSize: fontSize, weight: .medium)

            for match in matches {
                textStorage.addAttribute(.foregroundColor, value: hashtagColor, range: match.range)
                textStorage.addAttribute(.font, value: hashtagFont, range: match.range)
            }
        }
    }
}
