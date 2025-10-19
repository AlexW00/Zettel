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
        let shape = Capsule(style: .continuous)
        
        Text("tags.hashtag_prefix".localized(tagName))
            .font(.system(size: compact ? LayoutConstants.FontSize.caption : LayoutConstants.FontSize.small, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.secondaryText)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.medium)
            .padding(.vertical, compact ? LayoutConstants.Padding.extraSmall : LayoutConstants.Padding.small)
            .background(shape.fill(Color.tagBackground))
            .overlay(
                shape
                    .stroke(Color.separator.opacity(0.2), lineWidth: compact ? 0.6 : 0.8)
            )
            .contentShape(shape)
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
                        .foregroundStyle(Color.tertiaryText)
                        .padding(.horizontal, compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.small)
                        .padding(.vertical, compact ? 1 : LayoutConstants.Padding.extraSmall)
                        .background(
                            Capsule(style: .continuous).fill(Color.tagBackground)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.separator.opacity(0.2), lineWidth: compact ? 0.6 : 0.8)
                        )
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

struct LiquidGlassTagBackground<ShapeType: InsettableShape>: View {
    let shape: ShapeType
    let tint: Color?
    let highlight: Bool
    
    init(shape: ShapeType, tint: Color? = nil, highlight: Bool = false) {
        self.shape = shape
        self.tint = tint
        self.highlight = highlight
    }
    
    var body: some View {
        let accent = tint ?? Color.white
        let rimColor = accent.opacity(highlight ? 0.55 : 0.28)
        let beamGradient = LinearGradient(
            colors: [
                Color.white.opacity(highlight ? 0.55 : 0.32),
                accent.opacity(highlight ? 0.25 : 0.05),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        return shape
            .fill(Color.white.opacity(highlight ? 0.1 : 0.06))
            .overlay(
                shape
                    .fill(beamGradient)
                    .blur(radius: highlight ? 4 : 3)
                    .blendMode(.screen)
            )
            .overlay(
                shape
                    .strokeBorder(rimColor, lineWidth: highlight ? 1.2 : 0.8)
            )
            .overlay(
                shape
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                    .blendMode(.plusLighter)
            )
            .background(
                shape
                    .fill(Color.white.opacity(0.02))
                    .blur(radius: highlight ? 12 : 8)
            )
            .compositingGroup()
            .shadow(color: accent.opacity(highlight ? 0.28 : 0.14), radius: highlight ? 12 : 7, x: 0, y: highlight ? 6 : 3)
    }
}
