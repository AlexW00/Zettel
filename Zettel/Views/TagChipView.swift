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
            .foregroundStyle(Color.primaryText)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.medium)
            .padding(.vertical, compact ? LayoutConstants.Padding.extraSmall : LayoutConstants.Padding.small)
            .background {
                shape.fill(Color.clear)
                    .glassEffect(.regular, in: shape)
            }
            .contentShape(shape)
    }
}

struct TagListView: View {
    let tags: [String]
    let maxTags: Int
    let compact: Bool
    
    @State private var isOverflowing = false
    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    init(tags: [String], maxTags: Int = 3, compact: Bool = false) {
        self.tags = tags
        self.maxTags = maxTags
        self.compact = compact
    }
    
    var body: some View {
        if !tags.isEmpty {
            GeometryReader { geometry in
                HStack(spacing: compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.small) {
                    ForEach(Array(tags.prefix(maxTags)), id: \.self) { tag in
                        TagChipView(tagName: tag, compact: compact)
                    }
                    
                    if tags.count > maxTags {
                        let shape = Capsule(style: .continuous)
                        Text("overview.additional_tags".localized(tags.count - maxTags))
                            .font(Font.system(size: compact ? LayoutConstants.FontSize.caption - 1 : LayoutConstants.FontSize.caption, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                            .padding(.horizontal, compact ? LayoutConstants.Padding.small : LayoutConstants.Padding.small)
                            .padding(.vertical, compact ? 1 : LayoutConstants.Padding.extraSmall)
                            .background {
                                shape.fill(Color.clear)
                                    .glassEffect(.regular, in: shape)
                            }
                            .layoutPriority(-1)
                    }
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: TagContentWidthKey.self,
                            value: contentGeometry.size.width
                        )
                    }
                }
                .onPreferenceChange(TagContentWidthKey.self) { width in
                    contentWidth = width
                    isOverflowing = width > containerWidth
                }
                .frame(maxWidth: geometry.size.width, alignment: .leading)
                .clipped()
                .mask {
                    if isOverflowing {
                        HStack(spacing: 0) {
                            Color.black
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 24)
                        }
                    } else {
                        Color.black
                    }
                }
                .onAppear {
                    containerWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    containerWidth = newWidth
                    isOverflowing = contentWidth > newWidth
                }
            }
            .frame(height: compact ? 20 : 26) // Fixed height to prevent layout jumps
        }
    }
}

private struct TagContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
