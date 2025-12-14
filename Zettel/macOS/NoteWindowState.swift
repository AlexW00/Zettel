//
//  NoteWindowState.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Foundation
import Combine

@MainActor
final class NoteWindowState: ObservableObject {
    @Published var isCommandPaletteVisible = false
    @Published var isNotesPopoverVisible = false
    @Published var isRenamePopoverVisible = false
    @Published var renameDraft = ""
    @Published var banner: ErrorBanner?
}
