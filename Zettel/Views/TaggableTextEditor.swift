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
    
    init(text: Binding<String>, 
         font: UIFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
         foregroundColor: Color = .primaryText) {
        self._text = text
        self.font = font
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        TagTextViewRepresentable(
            text: $text,
            font: font,
            foregroundColor: foregroundColor,
            noteStore: noteStore
        )
    }
}

// UIViewRepresentable wrapper for the tag-aware text view
struct TagTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let foregroundColor: Color
    let noteStore: NoteStore
    
    func makeUIView(context: Context) -> TagTextView {
        let textView = TagTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = UIColor(foregroundColor)
        textView.backgroundColor = UIColor.clear
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.noteStore = noteStore
        
        // Disable autocorrect and other automatic text features
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
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
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTagSuggestionBar()
        setupTextInputTraits()
    }
    
    private func setupTextInputTraits() {
        // Disable autocorrect and other automatic text features
        autocorrectionType = .no
        spellCheckingType = .no
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

// Horizontal tag suggestion bar that appears above the keyboard
class TagSuggestionBar: UIView {
    var onTagSelected: ((String) -> Void)?
    
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let backgroundView = UIView()
    
    private var currentSuggestions: [Tag] = []
    private var currentPartial: String = ""
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Set initial height
        frame.size.height = 50
        
        // Background with transparent effect
        backgroundColor = UIColor.clear
        addSubview(backgroundView)
        backgroundView.backgroundColor = UIColor.clear
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Scroll view setup
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        backgroundView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -8)
        ])
        
        // Stack view setup
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // No longer initially hidden since we manage visibility at the text view level
    }
    
    func updateSuggestions(_ suggestions: [Tag], partial: String) {
        currentSuggestions = suggestions
        currentPartial = partial
        
        // Clear existing suggestion views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add suggestion chips
        for suggestion in suggestions.prefix(10) { // Limit to 10 suggestions
            let chip = createSuggestionChip(for: suggestion)
            stackView.addArrangedSubview(chip)
        }
    }
    
    private func createSuggestionChip(for tag: Tag) -> UIView {
        var config = UIButton.Configuration.filled()
        config.title = tag.displayName
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            return outgoing
        }
        config.baseBackgroundColor = UIColor.systemFill
        config.baseForegroundColor = UIColor.label
        config.cornerStyle = .fixed
        config.background.cornerRadius = 16
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        
        let button = UIButton(configuration: config)
        
        // Store the tag name in the button's accessibilityIdentifier for retrieval
        button.accessibilityIdentifier = tag.displayName
        button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let tagName = sender.accessibilityIdentifier else { return }
        onTagSelected?(tagName)
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
