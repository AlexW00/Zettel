//
//  TitlebarTitleView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI

struct TitlebarTitleView: View {
    @ObservedObject var document: NoteDocument
    @ObservedObject var state: NoteWindowState

    @FocusState private var isRenameFieldFocused: Bool

    private var titleText: String {
        document.session.displayName
    }

    private var renamePopoverBinding: Binding<Bool> {
        Binding(
            get: { state.isRenamePopoverVisible },
            set: { newValue in
                guard state.isRenamePopoverVisible != newValue else { return }
                DispatchQueue.main.async {
                    state.isRenamePopoverVisible = newValue
                }
            }
        )
    }

    private var renameDraftBinding: Binding<String> {
        Binding(
            get: { state.renameDraft },
            set: { newValue in
                guard state.renameDraft != newValue else { return }
                DispatchQueue.main.async {
                    state.renameDraft = newValue
                }
            }
        )
    }

    var body: some View {
        titleContent
            .contentShape(Rectangle())
            .onTapGesture(perform: toggleRenamePopover)
            .help("Rename Note")
            .accessibilityLabel(titleText)
            .accessibilityAddTraits(.isButton)
            .popover(isPresented: renamePopoverBinding, arrowEdge: .top) {
                TextField("Title", text: renameDraftBinding)
                    .textFieldStyle(.roundedBorder)
                    .focused($isRenameFieldFocused)
                    .frame(width: 220)
                    .onSubmit { commitRename() }
                    .onExitCommand { cancelRename() }
                    .padding(16)
                    .frame(width: 260)
                .onAppear { prepareRename() }
                .onDisappear { cleanupRenameState() }
            }
    }

    private var titleContent: some View {
        Text(titleText)
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .frame(height: 28)
    }

    private func toggleRenamePopover() {
        if state.isRenamePopoverVisible {
            cancelRename()
        } else {
            openRenamePopover()
        }
    }

    private func openRenamePopover() {
        state.isNotesPopoverVisible = false
        state.renameDraft = titleText
        state.isRenamePopoverVisible = true
    }

    private func prepareRename() {
        state.renameDraft = titleText
        DispatchQueue.main.async {
            self.isRenameFieldFocused = true
        }
    }

    private func cleanupRenameState() {
        state.renameDraft = titleText
        isRenameFieldFocused = false
    }

    private func commitRename() {
        let success = document.rename(to: state.renameDraft)
        if success {
            state.isRenamePopoverVisible = false
        } else {
            DispatchQueue.main.async {
                self.isRenameFieldFocused = true
            }
        }
    }

    private func cancelRename() {
        state.isRenamePopoverVisible = false
        state.renameDraft = titleText
    }
}
