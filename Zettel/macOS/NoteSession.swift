//
//  NoteSession.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Foundation

struct NoteSession: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var url: URL?
    var text: String
    var provisionalTitle: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        url: URL? = nil,
        text: String = "",
        provisionalTitle: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.url = url
        self.text = text
        self.provisionalTitle = provisionalTitle
    }

    var displayName: String {
        if let url {
            return url.deletingPathExtension().lastPathComponent
        }
        if let provisionalTitle, provisionalTitle.isEmpty == false {
            return provisionalTitle
        }
        return "Untitled"
    }
}
