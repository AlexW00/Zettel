//
//  OverviewGrid.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI

struct OverviewGrid: View {
    @ObservedObject var noteStore: NoteStore
    @Binding var showArchive: Bool
    @EnvironmentObject var backgroundStore: BackgroundStore
    @State private var selectedNote: Note?
    @State private var isSelectionMode = false
    @State private var selectedNotes = Set<String>()
    @State private var searchText = ""
    @State private var searchBarRevealed = false
    @Environment(\.navigationGestureActive) private var navigationGestureActive
    @Environment(\.colorScheme) var colorScheme

    // Design system constants
    private let cardCornerRadius: CGFloat = 14
    private let shadowRadius: CGFloat = 3
    private let verticalStackSpacing: CGFloat = 24
    private let popularTagLimit = 50
    private let popularTagsGridMinimumWidth: CGFloat = 96

    // Dynamic sizing based on screen width

    private func cardHeight(for screenWidth: CGFloat) -> CGFloat {
        let safeWidth = screenWidth.safeCGFloat(fallback: 320) // Default iPhone width

        // iPhone: ~180px, iPad: ~280-350px
        if safeWidth > 600 { // iPad
            return min(350, max(280, safeWidth.safeDivide(by: 3, fallback: 280)))
        } else { // iPhone
            return max(180, safeWidth.safeMultiply(by: 0.5, fallback: 180))
        }
    }

    private func gridSpacing(for screenWidth: CGFloat) -> CGFloat {
        // Ensure screenWidth is valid and finite
        guard screenWidth.isFinite && screenWidth > 0 else { return 16 }

        // Scale spacing with screen size
        return screenWidth > 600 ? 24 : 16
    }
    
    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var searchTokens: [String] {
        trimmedSearchText
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
    }
    
    private var isSearching: Bool {
        !searchTokens.isEmpty
    }
    
    private var popularSearchTags: [Tag] {
        noteStore.tagStore.getMostPopularTags(limit: popularTagLimit)
    }

    // Filtered notes based on selected tags
    private var filteredNotes: [Note] {
        let baseNotes = noteStore.archivedNotes
        guard isSearching else {
            return baseNotes
        }
        
        return baseNotes.filter { note in
            matchesSearch(note: note, tokens: searchTokens)
        }
    }
    
    /// Returns transparent background when custom background is set, otherwise default app background
    @ViewBuilder
    private var backgroundLayer: some View {
        if backgroundStore.hasCustomBackground {
            Color.clear
        } else {
            Color.appBackground
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack(alignment: .top) {
                    backgroundLayer
                        .ignoresSafeArea()
                    PullToRevealScrollView(
                        searchText: $searchText,
                        isSearchRevealed: $searchBarRevealed,
                        colorScheme: colorScheme,
                        hasCustomBackground: backgroundStore.hasCustomBackground
                    ) {
                        VStack(alignment: .leading, spacing: verticalStackSpacing) {
                            if searchBarRevealed && !popularSearchTags.isEmpty {
                                VStack(alignment: .leading, spacing: LayoutConstants.Padding.medium) {
                                    Text(StringConstants.Search.popularTags.localized)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondaryText)
                                    
                                    LazyVGrid(
                                        columns: [
                                            GridItem(
                                                .adaptive(minimum: popularTagsGridMinimumWidth),
                                                spacing: LayoutConstants.Padding.medium,
                                                alignment: .leading
                                            )
                                        ],
                                        alignment: .leading,
                                        spacing: LayoutConstants.Padding.medium
                                    ) {
                                        ForEach(popularSearchTags) { tag in
                                            Button {
                                                searchText = tag.displayName
                                            } label: {
                                                TagChipView(tagName: tag.displayName)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            
                            if noteStore.isInitialLoadingNotes {
                                LoadingStateView(
                                    error: noteStore.loadingError,
                                    retryAction: noteStore.loadingError != nil ? {
                                        noteStore.retryNoteLoading()
                                    } : nil
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if filteredNotes.isEmpty {
                                if isSearching {
                                    SearchEmptyStateView(query: trimmedSearchText)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    EmptyStateView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: gridSpacing(for: geometry.size.width)),
                                        GridItem(.flexible(), spacing: gridSpacing(for: geometry.size.width))
                                    ],
                                    spacing: gridSpacing(for: geometry.size.width)
                                ) {
                                    ForEach(filteredNotes) { note in
                                        NoteCard(
                                            note: note,
                                            isSelected: selectedNotes.contains(note.filename),
                                            isSelectionMode: isSelectionMode
                                        )
                                        .frame(height: cardHeight(for: geometry.size.width))
                                        .contextMenu {
                                            if !isSelectionMode {
                                                Button(role: .destructive) {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        noteStore.deleteArchivedNote(note)
                                                    }
                                                } label: {
                                                    Label(StringConstants.Actions.delete.localized, systemImage: "trash")
                                                }
                                            }
                                        }
                                        .onTapGesture {
                                            if isSelectionMode {
                                                toggleNoteSelection(note)
                                            } else if !note.isDownloading {
                                                noteStore.loadArchivedNoteAsCurrent(note)
                                                showArchive = false
                                            }
                                        }
                                    }
                                }
                                .padding(.top, LayoutConstants.Padding.small)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, LayoutConstants.Padding.large)
                        .padding(.bottom, LayoutConstants.Padding.extraLarge)
                    }
                    .disabled(navigationGestureActive)
                    .scrollContentBackground(.hidden)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar {
                    // Search button on the leading edge
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !isSelectionMode {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    searchBarRevealed.toggle()
                                    if !searchBarRevealed {
                                        searchText = ""
                                    }
                                }
                            } label: {
                                Image(systemName: searchBarRevealed ? "xmark" : "magnifyingglass")
                                    .foregroundColor(.primaryText)
                                    .font(.system(size: 18, weight: .medium))
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .frame(width: LayoutConstants.Size.toolbarButton, height: LayoutConstants.Size.toolbarButton)
                            .adaptiveGlassEffect(
                                in: Circle(),
                                colorScheme: colorScheme,
                                hasCustomBackground: backgroundStore.hasCustomBackground
                            )
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSelectionMode {
                            HStack {
                                Button(action: deleteSelectedNotes) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.primaryText)
                                        .font(.system(size: 20))
                                }
                                .frame(width: LayoutConstants.Size.toolbarButton, height: LayoutConstants.Size.toolbarButton)
                                .adaptiveGlassEffect(
                                    in: Circle(),
                                    colorScheme: colorScheme,
                                    hasCustomBackground: backgroundStore.hasCustomBackground
                                )
                                .disabled(selectedNotes.isEmpty)

                                Button(StringConstants.Actions.cancel.localized) {
                                    exitSelectionMode()
                                }
                                .foregroundColor(.primaryText)
                                .padding(.horizontal, 16)
                                .frame(height: LayoutConstants.Size.toolbarButton)
                                .adaptiveGlassEffect(
                                    in: Capsule(),
                                    colorScheme: colorScheme,
                                    hasCustomBackground: backgroundStore.hasCustomBackground
                                )
                            }
                        } else {
                            Button(action: enterSelectionMode) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.primaryText)
                                    .font(.system(size: 22))
                            }
                            .frame(width: LayoutConstants.Size.toolbarButton, height: LayoutConstants.Size.toolbarButton)
                            .adaptiveGlassEffect(
                                in: Circle(),
                                colorScheme: colorScheme,
                                hasCustomBackground: backgroundStore.hasCustomBackground
                            )
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .transparentBackground() // Clear the hosting controller background
            } // NavigationStack
        } // GeometryReader
    }
}

struct NoteCard: View {
    let note: Note
    var isSelected: Bool = false
    var isSelectionMode: Bool = false

    private let cardCornerRadius: CGFloat = 14

    @State private var wiggleAnimation = false

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var backgroundStore: BackgroundStore

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header with title
                Text(note.title)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .padding(.bottom, 8)
                    .shadow(color: colorScheme == .dark ? .black.opacity(ThemeConstants.Opacity.textShadowDark) : .white.opacity(ThemeConstants.Opacity.textShadowLight), radius: ThemeConstants.Shadow.textRadius, x: 0, y: 1)

                // Content preview with overflow handling
                ZStack(alignment: .bottom) {
                    if note.isCloudStub {
                        // Show different states for cloud files
                        VStack {
                            if note.isDownloading {
                                // Show downloading indicator
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.bottom, 4)
                                Text("loading.downloading".localized)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(.secondaryText.opacity(0.8))
                            } else {
                                // Show cloud icon for undownloaded files
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondaryText.opacity(0.6))
                                Text("loading.tap_to_download".localized)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(.secondaryText.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text(note.contentPreview(maxLines: 6))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.75))
                            .lineLimit(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .shadow(color: colorScheme == .dark ? .black.opacity(ThemeConstants.Opacity.textShadowDark) : .white.opacity(ThemeConstants.Opacity.textShadowLight), radius: ThemeConstants.Shadow.textRadius, x: 0, y: 1)
                    }
                }
                .clipped()
                
                Spacer()

                // Tags positioned at the bottom
                let noteTags = Array(note.extractedTags.sorted())
                if !noteTags.isEmpty {
                    TagListView(tags: noteTags, maxTags: 2, compact: true)
                        .padding(.top, 4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(isSelected ? Color.accentColor.opacity(Color.lightOpacity) : Color.clear)
                    .adaptiveGlassEffect(
                        in: RoundedRectangle(cornerRadius: cardCornerRadius),
                        colorScheme: colorScheme,
                        hasCustomBackground: backgroundStore.hasCustomBackground
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .opacity(note.isDownloading ? 0.6 : 1.0) // Reduce opacity for downloading notes
            .rotationEffect(.degrees(isSelectionMode && !isSelected ? (wiggleAnimation ? 1 : -1) : 0))
            .animation(
                isSelectionMode && !isSelected ?
                Animation.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true) : nil,
                value: wiggleAnimation
            )

            // Selection indicator
            if isSelectionMode {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .inactiveColor)
                            .font(.title2)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 24, height: 24)
                            )
                    }
                    Spacer()
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .onAppear {
            if isSelectionMode && !isSelected {
                wiggleAnimation.toggle()
            }
        }
        .onChange(of: isSelectionMode) { _, newValue in
            if newValue && !isSelected {
                wiggleAnimation.toggle()
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.tertiaryText)
            
            Text(StringConstants.Overview.emptyStateMessage.localized)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // Ensures the entire area is tappable if needed
    }
}

struct SearchEmptyStateView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.tertiaryText)
            
            Text(StringConstants.Search.noResultsTitle.localized(query))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(StringConstants.Search.noResultsMessage.localized)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.tertiaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Search Helpers

extension OverviewGrid {
    private func matchesSearch(note: Note, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        
        let normalizedTitle = normalizeForSearch(note.title)
        let normalizedContent = normalizeForSearch(note.content)
        let normalizedFilename = normalizeForSearch(note.filename)
        let normalizedTags = note.extractedTags.map { normalizeForSearch($0) }
        
        return tokens.allSatisfy { token in
            normalizedTitle.contains(token) ||
            normalizedContent.contains(token) ||
            normalizedFilename.contains(token) ||
            normalizedTags.contains(where: { $0.contains(token) })
        }
    }
    
    private func normalizeForSearch(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

// MARK: - Selection Actions Extension

extension OverviewGrid {
    private func deleteNote(_ note: Note) {
        withAnimation(.easeInOut(duration: 0.2)) {
            noteStore.deleteArchivedNote(note)
        }
    }
    
    private func enterSelectionMode() {
        withAnimation {
            isSelectionMode = true
            selectedNotes.removeAll()
        }
    }
    
    private func exitSelectionMode() {
        withAnimation {
            isSelectionMode = false
            selectedNotes.removeAll()
        }
    }
    
    private func toggleNoteSelection(_ note: Note) {
        withAnimation {
            if selectedNotes.contains(note.filename) {
                selectedNotes.remove(note.filename)
            } else {
                selectedNotes.insert(note.filename)
            }
        }
    }
    
    private func deleteSelectedNotes() {
        withAnimation {
            for filename in selectedNotes {
                noteStore.deleteArchivedNote(withFilename: filename)
            }
            exitSelectionMode()
        }
    }
}


// MARK: - Preview

struct OverviewGrid_Previews: PreviewProvider {
    static var previews: some View {
        let noteStore = NoteStore()
        
        // Add some sample notes for preview
        let sampleNotes = [
            Note(title: "Sample Note 1", content: "This is a sample note with some content to show how the preview looks in the grid."),
            Note(title: "Sample Note 2", content: "Another note with different content. This one is a bit longer to test the line limiting."),
            Note(title: "Short Note", content: "Brief."),
            Note(title: "Empty Note", content: "")
        ]
        
        noteStore.archivedNotes = sampleNotes
        
        return OverviewGrid(noteStore: noteStore, showArchive: .constant(true))
            .environmentObject(BackgroundStore())
    }
}
