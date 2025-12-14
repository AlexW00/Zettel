//
//  ErrorBanner.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Foundation

struct ErrorBanner: Identifiable {
    enum Severity {
        case info
        case warning
        case error
    }

    let id = UUID()
    let message: String
    let severity: Severity
    let error: NSError?
    let isPersistent: Bool

    init(message: String, severity: Severity = .error, error: NSError? = nil, isPersistent: Bool = false) {
        self.message = message
        self.severity = severity
        self.error = error
        self.isPersistent = isPersistent
    }
}

