//
//  TagChipView.swift
//  Zettel
//

import SwiftUI

struct TagChipView: View {
    let tagName: String
    let compact: Bool
    
    init(tagName: String, compact: Bool = false) {
        self.tagName = tagName
        self.compact = compact
    }
    
    var body: some View {
        Text("tags.hashtag_prefix".localized(tagName))
            .font(.system(size: compact ? LayoutConstants.FontSize.caption : LayoutConstants.FontSize.small, weight: .medium, design: .monospaced))
            .foregroundColor(.secondaryText)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.medium)
            .padding(.vertical, compact ? LayoutConstants.Padding.extraSmall : LayoutConstants.Padding.small)
            .background(Color.separator.opacity(ThemeConstants.Opacity.medium))
            .cornerRadius(compact ? LayoutConstants.CornerRadius.small : LayoutConstants.CornerRadius.small)
    }
}

struct TagListView: View {
    let tags: [String]
    let maxTags: Int
    let compact: Bool
    
    init(tags: [String], maxTags: Int = 3, compact: Bool = false) {
        self.tags = tags
        self.maxTags = maxTags
        self.compact = compact
    }
    
    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.small) {
                ForEach(Array(tags.prefix(maxTags)), id: \.self) { tag in
                    TagChipView(tagName: tag, compact: compact)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                if tags.count > maxTags {
                    Text("overview.additional_tags".localized(tags.count - maxTags))
                        .font(Font.system(size: compact ? LayoutConstants.FontSize.caption - 1 : LayoutConstants.FontSize.caption, weight: .medium))
                        .foregroundColor(.tertiaryText)
                        .padding(.horizontal, compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.small)
                        .padding(.vertical, compact ? 1 : LayoutConstants.Padding.extraSmall)
                        .background(Color.separator.opacity(ThemeConstants.Opacity.medium - 0.1))
                        .cornerRadius(compact ? LayoutConstants.CornerRadius.small - 1 : LayoutConstants.CornerRadius.small)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(1)
            .truncationMode(.tail)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TagListView(tags: ["work", "important", "meeting", "urgent"], maxTags: 2)
        TagListView(tags: ["personal", "ideas"], compact: true)
        TagChipView(tagName: "example")
    }
    .padding()
}
