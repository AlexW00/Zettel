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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Configure text view
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Appearance
        textView.font = .systemFont(ofSize: 15, weight: .regular)
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

        func applyHashtagHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string

            // Reset to default style
            let defaultFont = NSFont.systemFont(ofSize: 15, weight: .regular)
            let defaultColor = NSColor.labelColor
            textStorage.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
            textStorage.addAttribute(.font, value: defaultFont, range: fullRange)

            // Highlight hashtags
            let regex = TagParser.regexInternal
            let matches = regex.matches(in: text, options: [], range: fullRange)

            let hashtagColor = NSColor.systemBlue
            let hashtagFont = NSFont.systemFont(ofSize: 15, weight: .medium)

            for match in matches {
                textStorage.addAttribute(.foregroundColor, value: hashtagColor, range: match.range)
                textStorage.addAttribute(.font, value: hashtagFont, range: match.range)
            }
        }
    }
}
