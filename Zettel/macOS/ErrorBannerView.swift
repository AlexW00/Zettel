//
//  ErrorBannerView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import AppKit

struct ErrorBannerView: View {
    let banner: ErrorBanner
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.message)
                    .font(.headline)
                if let error = banner.error {
                    Button("Details…") {
                        NSApp.presentError(error)
                    }
                    .buttonStyle(.link)
                }
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        )
    }

    private var iconName: String {
        switch banner.severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "exclamationmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch banner.severity {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}
