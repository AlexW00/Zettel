//
//  PullToRevealSearchBar.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI

// MARK: - Scroll Offset Tracking

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Pull-to-Reveal Search Bar

struct PullToRevealSearchBar: View {
    @Binding var searchText: String
    @Binding var isRevealed: Bool
    let colorScheme: ColorScheme
    let hasCustomBackground: Bool
    let scrollOffset: CGFloat
    let isDragging: Bool // Only show during actual finger drag
    
    @FocusState private var isFocused: Bool
    
    // Constants
    private let searchBarHeight: CGFloat = LayoutConstants.Size.searchBarHeight
    private let horizontalPadding: CGFloat = 16
    private let iconSize: CGFloat = 16
    
    // Calculate display properties based on state and scroll
    private var currentHeight: CGFloat {
        if isRevealed {
            return searchBarHeight
        }
        // Only show during active drag, hide during momentum
        guard isDragging else { return 0 }
        return max(0, min(searchBarHeight, scrollOffset))
    }
    
    private var currentOpacity: Double {
        if isRevealed {
            return 1.0
        }
        // Only show during active drag, hide during momentum
        guard isDragging else { return 0 }
        return max(0, min(1.0, Double(scrollOffset) / Double(searchBarHeight)))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.secondaryText)
            
            // Search text field
            TextField(StringConstants.Search.prompt.localized, text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.primaryText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
            
            // Clear button
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: searchBarHeight)
        .adaptiveGlassEffect(
            in: Capsule(),
            colorScheme: colorScheme,
            hasCustomBackground: hasCustomBackground
        )
        .frame(height: currentHeight)
        .opacity(currentOpacity)
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isRevealed)
        .onChange(of: isRevealed) { _, newValue in
            if newValue {
                // Auto-focus when revealed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }
            } else {
                // Clear focus when hidden
                isFocused = false
            }
        }
        .onChange(of: isFocused) { _, newValue in
            // Hide search bar when keyboard dismissed and search is empty
            if !newValue && searchText.isEmpty && isRevealed {
                isRevealed = false
            }
        }
    }
}

// MARK: - Pull-to-Reveal Container

struct PullToRevealScrollView<Content: View>: View {
    @Binding var searchText: String
    @Binding var isSearchRevealed: Bool
    let colorScheme: ColorScheme
    let hasCustomBackground: Bool
    @ViewBuilder let content: () -> Content
    
    // Threshold for triggering reveal (pull distance in points)
    private let revealThreshold: CGFloat = 65
    private let hideThreshold: CGFloat = -100
    
    // Track scroll state
    @State private var scrollOffset: CGFloat = 0
    @State private var outerMinY: CGFloat = 0
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { outerProxy in
            let outerFrame = outerProxy.frame(in: .global)
            
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .top) {
                        // Tracker
                        GeometryReader { innerProxy in
                            let innerFrame = innerProxy.frame(in: .global)
                            let currentOffset = innerFrame.minY - outerFrame.minY
                            
                            Color.clear
                                // Direct layout observation - bypassing PreferenceKeys which can fail in ScrollViews
                                .onChange(of: innerFrame.minY) { _ in
                                    updateOffset(currentOffset)
                                }
                                .onAppear {
                                    updateOffset(currentOffset)
                                }
                        }
                        .frame(height: 0)
                        
                        VStack(spacing: 0) {
                            // Search bar (dynamic reveal)
                            PullToRevealSearchBar(
                                searchText: $searchText,
                                isRevealed: $isSearchRevealed,
                                colorScheme: colorScheme,
                                hasCustomBackground: hasCustomBackground,
                                scrollOffset: scrollOffset,
                                isDragging: isDragging
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, isSearchRevealed ? LayoutConstants.Padding.medium : 0)
                            .id("top")
                            
                            // Main content
                            content()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .scrollBounceBehavior(.always)
                .onChange(of: isSearchRevealed) { _, revealed in
                    if revealed {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in isDragging = true }
                    .onEnded { _ in isDragging = false }
            )

        }
    }
    
    private func updateOffset(_ offset: CGFloat) {
        // Avoid redundant updates
        guard abs(scrollOffset - offset) > 0.5 else { return }
        
        DispatchQueue.main.async {
            self.scrollOffset = offset
            self.handleScrollOffset(offset)
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        // Detect overscroll at top - ONLY when dragging
        if offset > revealThreshold && !isSearchRevealed && isDragging {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isSearchRevealed = true
            }
        }
        
        // Detect scrolling down
        if offset < hideThreshold && isSearchRevealed && searchText.isEmpty && isDragging {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearchRevealed = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        @State private var isRevealed = false
        
        var body: some View {
            PullToRevealScrollView(
                searchText: $searchText,
                isSearchRevealed: $isRevealed,
                colorScheme: .light,
                hasCustomBackground: false
            ) {
                VStack(spacing: 16) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 80)
                            .overlay(Text("Item \(index)"))
                    }
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
        

