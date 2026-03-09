//
//  TaggableTextEditor.swift
//  Zettel
//
//  Created by GitHub Copilot on 04.07.25.
//

import SwiftUI
import UIKit

struct TaggableTextEditor: View {
    @Binding var text: String
    @EnvironmentObject var noteStore: NoteStore

    let font: UIFont
    let foregroundColor: Color
    let isEditingEnabled: Bool
    let highlightRange: NSRange?
    
    init(text: Binding<String>,
         font: UIFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
         foregroundColor: Color = .primaryText,
         isEditingEnabled: Bool = true,
         highlightRange: NSRange? = nil) {
        self._text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.isEditingEnabled = isEditingEnabled
        self.highlightRange = highlightRange
    }
    
    var body: some View {
        TagTextViewRepresentable(
            text: $text,
            font: font,
            foregroundColor: foregroundColor,
            noteStore: noteStore,
            isEditingEnabled: isEditingEnabled,
            highlightRange: highlightRange
        )
    }
}

// UIViewRepresentable wrapper for the tag-aware text view
struct TagTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let foregroundColor: Color
    let noteStore: NoteStore
    let isEditingEnabled: Bool
    let highlightRange: NSRange?
    
    func makeUIView(context: Context) -> TagTextView {
        let textView = TagTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = UIColor(foregroundColor)
        textView.backgroundColor = UIColor.clear
        textView.isScrollEnabled = true
        textView.isEditable = isEditingEnabled
        textView.isSelectable = isEditingEnabled
        textView.isUserInteractionEnabled = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.noteStore = noteStore
        textView.highlightedRange = highlightRange
        
        // Keep keyboard writing assistance enabled for note editing
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.autocapitalizationType = .sentences
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        
        return textView
    }
    
    func updateUIView(_ uiView: TagTextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            
            // Restore cursor position if possible
            if selectedRange.location <= text.count {
                uiView.selectedRange = selectedRange
            }
        }
        
        // Update font if it has changed
        if uiView.font != font {
            uiView.font = font
        }
        
        // Update text color if it has changed
        let newColor = UIColor(foregroundColor)
        if uiView.textColor != newColor {
            uiView.textColor = newColor
        }

        if uiView.isEditable != isEditingEnabled {
            uiView.isEditable = isEditingEnabled
            uiView.isSelectable = isEditingEnabled
        }

        if uiView.highlightedRange != highlightRange {
            uiView.highlightedRange = highlightRange
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TagTextViewRepresentable
        
        init(_ parent: TagTextViewRepresentable) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.text = textView.text
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelectionState(for: textView)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            updateSelectionState(for: textView)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            Task { @MainActor in
                self.parent.noteStore.isTextSelectionActive = false
            }
        }
        
        private func updateSelectionState(for textView: UITextView) {
            let hasSelection = textView.selectedRange.length > 0
            Task { @MainActor in
                self.parent.noteStore.isTextSelectionActive = hasSelection
            }
        }
    }
}

// MARK: - Auto-Bullet Support Types

private struct BulletInfo {
    enum BulletType {
        case dash
        case asterisk
        case numbered(Int)
    }
    
    let type: BulletType
    let prefix: String
}

// Custom UITextView with tag suggestion support
class TagTextView: UITextView {
    var noteStore: NoteStore?
    private var tagSuggestionBar: TagSuggestionBar?
    private var shouldShowSuggestions = false
    var highlightedRange: NSRange? {
        didSet { applyHighlight() }
    }
    private let highlightColor = UIColor.systemYellow.withAlphaComponent(0.24)
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTagSuggestionBar()
        setupTextInputTraits()
    }
    
    private func setupTextInputTraits() {
        // Keep keyboard writing assistance enabled for note editing
        autocorrectionType = .default
        spellCheckingType = .default
        autocapitalizationType = .sentences
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTagSuggestionBar()
        setupTextInputTraits()
    }
    
    private func setupTagSuggestionBar() {
        tagSuggestionBar = TagSuggestionBar()
        tagSuggestionBar?.onTagSelected = { [weak self] tagName in
            self?.insertTag(tagName)
        }
        // Don't set inputAccessoryView initially - only when needed
    }
    
    override func insertText(_ text: String) {
        // Handle auto-bullet functionality for newlines
        if text == "\n" {
            handleNewlineForAutoBullet()
        } else {
            super.insertText(text)
        }
        checkForTagSuggestions()
    }
    
    override func deleteBackward() {
        super.deleteBackward()
        checkForTagSuggestions()
    }
    
    private func checkForTagSuggestions() {
        guard let noteStore = noteStore else { return }
        
        let cursorPosition = selectedRange.location
        
        if let hashtagInfo = TagParser.findHashtagAtPosition(text, position: cursorPosition) {
            let suggestions = noteStore.tagStore.getMatchingTags(
                for: hashtagInfo.partial, 
                excludingCurrentTag: hashtagInfo.range, 
                fromText: text
            )
            
            if !suggestions.isEmpty {
                showTagSuggestionBar()
                tagSuggestionBar?.updateSuggestions(suggestions, partial: hashtagInfo.partial)
            } else {
                hideTagSuggestionBar()
            }
        } else {
            hideTagSuggestionBar()
        }
    }
    
    private func showTagSuggestionBar() {
        guard !shouldShowSuggestions else { return }
        shouldShowSuggestions = true
        inputAccessoryView = tagSuggestionBar
        reloadInputViews()
    }
    
    private func hideTagSuggestionBar() {
        guard shouldShowSuggestions else { return }
        shouldShowSuggestions = false
        inputAccessoryView = nil
        reloadInputViews()
    }

    private func applyHighlight() {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        guard let highlightRange = highlightedRange,
              highlightRange.length > 0,
              NSMaxRange(highlightRange) <= textStorage.length else { return }

        textStorage.addAttribute(.backgroundColor, value: highlightColor, range: highlightRange)
    }
    
    override func resignFirstResponder() -> Bool {
        hideTagSuggestionBar()
        return super.resignFirstResponder()
    }
    
    private func insertTag(_ tagName: String) {
        let cursorPosition = selectedRange.location
        
        if let hashtagInfo = TagParser.findHashtagAtPosition(text, position: cursorPosition) {
            let newText = TagParser.replaceHashtag(in: text, range: hashtagInfo.range, with: tagName)
            text = newText
            
            // Move cursor to after the completed tag
            let newCursorPosition = hashtagInfo.range.location + tagName.count + 1 // +1 for #
            selectedRange = NSRange(location: newCursorPosition, length: 0)
            
            // Manually trigger the delegate method to update the SwiftUI binding
            delegate?.textViewDidChange?(self)
            
            hideTagSuggestionBar()
        }
    }
    
    // MARK: - Auto-Bullet Functionality
    
    private func handleNewlineForAutoBullet() {
        let cursorPosition = selectedRange.location
        let textBeforeCursor = String(text.prefix(cursorPosition))
        
        // Find the current line (text after last newline)
        let lines = textBeforeCursor.components(separatedBy: "\n")
        let currentLine = lines.last ?? ""
        
        if let bulletInfo = detectBulletPattern(in: currentLine) {
            if isEmptyBulletLine(currentLine, bulletInfo: bulletInfo) {
                // User wants a simple newline, not removal.
                super.insertText("\n")
            } else {
                // Insert next bullet point
                insertNextBullet(bulletInfo: bulletInfo)
            }
        } else {
            // Normal newline behavior
            super.insertText("\n")
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
        super.insertText(nextBulletPrefix)
        
        // Manually trigger the delegate method to update the SwiftUI binding
        delegate?.textViewDidChange?(self)
    }
}

// MARK: - Liquid Glass Tag Suggestion Content (SwiftUI)

/// SwiftUI view rendering tag suggestion chips with liquid glass effect
private struct TagSuggestionsContentView: View {
    let suggestions: [Tag]
    let onTagSelected: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions.prefix(10)) { tag in
                    Button {
                        onTagSelected(tag.displayName)
                    } label: {
                        Text(tag.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

// Horizontal tag suggestion bar that appears above the keyboard
class TagSuggestionBar: UIView {
    var onTagSelected: ((String) -> Void)?

    private var hostingController: UIHostingController<TagSuggestionsContentView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        frame.size.height = 66
        backgroundColor = .clear

        let content = TagSuggestionsContentView(
            suggestions: [],
            onTagSelected: { [weak self] tagName in
                self?.onTagSelected?(tagName)
            }
        )
        let hc = UIHostingController(rootView: content)
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hc.view)
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        hostingController = hc
    }

    func updateSuggestions(_ suggestions: [Tag], partial: String) {
        hostingController?.rootView = TagSuggestionsContentView(
            suggestions: suggestions,
            onTagSelected: { [weak self] tagName in
                self?.onTagSelected?(tagName)
            }
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Hello #world this is a #test"
        
        var body: some View {
            TaggableTextEditor(text: $text)
                .padding()
                .environmentObject(NoteStore())
        }
    }
    
    return PreviewWrapper()
}
