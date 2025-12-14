//
//  NoteEditorView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import AppKit

struct NoteEditorView: NSViewRepresentable {
    @ObservedObject var document: NoteDocument
    @EnvironmentObject private var notesStore: NotesStore

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFindPanel = true
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.string = document.session.text
        textView.textContainerInset = NSSize(width: 18, height: 20)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        applyEditorAppearance(on: scrollView, textView: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        applyEditorAppearance(on: nsView, textView: textView)
        if textView.string != document.session.text {
            context.coordinator.applyDocumentText(document.session.text)
        }
    }

    private func applyEditorAppearance(on scrollView: NSScrollView, textView: NSTextView) {
        let backgroundColor = editorBackgroundColor(for: scrollView.effectiveAppearance)

        if scrollView.wantsLayer == false {
            scrollView.wantsLayer = true
        }
        scrollView.layer?.backgroundColor = backgroundColor.cgColor
        scrollView.layer?.isOpaque = true
        scrollView.layer?.cornerRadius = 12
        scrollView.layer?.masksToBounds = true

        scrollView.drawsBackground = true
        scrollView.backgroundColor = backgroundColor
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = backgroundColor

        textView.drawsBackground = true
        textView.wantsLayer = true
        textView.layer?.isOpaque = true
        textView.layer?.backgroundColor = backgroundColor.cgColor
        textView.backgroundColor = backgroundColor
    }

    private func editorBackgroundColor(for appearance: NSAppearance) -> NSColor {
        let isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let base = isDarkMode
            ? NSColor(calibratedWhite: 0.12, alpha: 1.0)
            : NSColor(calibratedWhite: 0.98, alpha: 1.0)
        return base
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private weak var document: NoteDocument?
        weak var textView: NSTextView?
        private var isUpdatingFromDocument = false

        init(document: NoteDocument) {
            self.document = document
        }

        func textDidChange(_ notification: Notification) {
            guard isUpdatingFromDocument == false,
                  let text = textView?.string else { return }
            document?.applyTextChange(text)
        }

        func applyDocumentText(_ text: String) {
            guard let textView else { return }
            isUpdatingFromDocument = true
            textView.string = text
            textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
            isUpdatingFromDocument = false
        }
    }
}
