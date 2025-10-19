import SwiftUI
import UIKit

struct SelectableTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont
    var foregroundColor: Color
    var textAlignment: NSTextAlignment
    var autocapitalizationType: UITextAutocapitalizationType
    
    @EnvironmentObject private var noteStore: NoteStore
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        font: UIFont = UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
        foregroundColor: Color = .primaryText,
        textAlignment: NSTextAlignment = .center,
        autocapitalizationType: UITextAutocapitalizationType = .sentences
    ) {
        self.placeholder = placeholder
        self._text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.textAlignment = textAlignment
        self.autocapitalizationType = autocapitalizationType
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.font = font
        textField.textColor = UIColor(foregroundColor)
        textField.textAlignment = textAlignment
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.contentVerticalAlignment = .center
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.placeholder = placeholder
        textField.clearButtonMode = .never
        textField.setContentHuggingPriority(.required, for: .vertical)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        if uiView.font != font {
            uiView.font = font
        }
        
        let uiColor = UIColor(foregroundColor)
        if uiView.textColor != uiColor {
            uiView.textColor = uiColor
        }
        
        if uiView.textAlignment != textAlignment {
            uiView.textAlignment = textAlignment
        }
        
        if uiView.autocapitalizationType != autocapitalizationType {
            uiView.autocapitalizationType = autocapitalizationType
        }
        
        if uiView.contentVerticalAlignment != .center {
            uiView.contentVerticalAlignment = .center
        }
        
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, context: Context) -> CGSize {
        let height = font.lineHeight + 12
        let width = proposal.width ?? UIView.noIntrinsicMetric
        return CGSize(width: width, height: height)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: SelectableTextField
        
        init(parent: SelectableTextField) {
            self.parent = parent
        }
        
        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            updateSelectionState(for: textField)
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            updateSelectionState(for: textField)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            Task { @MainActor in
                self.parent.noteStore.isTextSelectionActive = false
            }
        }
        
        private func updateSelectionState(for textField: UITextField) {
            let hasSelection: Bool
            if let range = textField.selectedTextRange {
                let length = textField.offset(from: range.start, to: range.end)
                hasSelection = length > 0
            } else {
                hasSelection = false
            }
            
            Task { @MainActor in
                self.parent.noteStore.isTextSelectionActive = hasSelection
            }
        }
    }
}
