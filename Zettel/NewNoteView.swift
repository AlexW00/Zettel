import SwiftUI

struct NewNoteView: View {
    @State private var content: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $content)
            .focused($isFocused)
            .padding()
            .navigationTitle("New Note")
            .onAppear { isFocused = true }
    }
}
