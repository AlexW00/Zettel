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
    @State private var selectedNote: Note?
    @State private var isSelectionMode = false
    @State private var selectedNotes = Set<String>()
    
    // Tag filtering
    @State private var selectedTagFilters: Set<String> = []
    @Environment(\.navigationGestureActive) private var navigationGestureActive

    // Design system constants
    private let cardCornerRadius: CGFloat = 14
    private let shadowRadius: CGFloat = 3
    private let verticalStackSpacing: CGFloat = 24

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
    
    // Filtered notes based on selected tags
    private var filteredNotes: [Note] {
        guard !selectedTagFilters.isEmpty else {
            return noteStore.archivedNotes
        }
        let filtered = noteStore.getNotesWithAllTags(selectedTagFilters)
        
        // Auto-clear filters if no notes match
        if filtered.isEmpty && !selectedTagFilters.isEmpty {
            DispatchQueue.main.async {
                selectedTagFilters.removeAll()
            }
        }
        
        // Sort filtered notes by last edit timestamp (most recent first)
        return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    // Available tags for selection based on current filter state
    private var availableTags: [Tag] {
        let currentNotes = selectedTagFilters.isEmpty ? noteStore.archivedNotes : noteStore.getNotesWithAllTags(selectedTagFilters)
        
        if selectedTagFilters.isEmpty {
            // No filters applied, show most popular tags
            return noteStore.tagStore.getMostPopularTags(limit: 50)
        } else if currentNotes.isEmpty {
            // Filters applied but no matching notes - this will trigger filter clearing
            return []
        } else {
            // Get all tags that appear in the currently filtered notes
            var availableTagNames: Set<String> = []
            for note in currentNotes {
                availableTagNames.formUnion(note.extractedTags)
            }
            
            // Convert to Tag objects and sort by usage count
            let availableTagObjects = availableTagNames.compactMap { tagName in
                noteStore.tagStore.getTag(byName: tagName)
            }.sorted { tag1, tag2 in
                if tag1.usageCount != tag2.usageCount {
                    return tag1.usageCount > tag2.usageCount
                }
                return tag1.displayName < tag2.displayName
            }
            
            return Array(availableTagObjects.prefix(50))
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack(alignment: .top) {
                    Color.appBackground
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: verticalStackSpacing) {
                            if !noteStore.tagStore.allTags.isEmpty {
                                TagFilterBar(
                                    availableTags: availableTags,
                                    selectedTags: $selectedTagFilters
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                                EmptyStateView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .coordinateSpace(name: "scrollContainer")
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSelectionMode {
                            HStack {
                                Button(action: deleteSelectedNotes) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.primaryText)
                                    }
                                    .disabled(selectedNotes.isEmpty)

                                    Button(StringConstants.Actions.cancel.localized) {
                                        exitSelectionMode()
                                    }
                                    .foregroundColor(.primaryText)
                                }
                        } else {
                            Button(action: enterSelectionMode) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.primaryText)
                            }
                        }
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            } // NavigationStack
        } // GeometryReader
    }
}

struct NoteCard: View {
    let note: Note
    var isSelected: Bool = false
    var isSelectionMode: Bool = false

    private let cardCornerRadius: CGFloat = 14
    private let shadowRadius: CGFloat = 3

    @State private var wiggleAnimation = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header with title
                Text(note.title)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .padding(.bottom, 8)

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
                            .foregroundColor(.secondaryText)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    // Gradient overlay for overflow indication (hidden in selection mode and for cloud stubs)
                    if !isSelectionMode && !note.isCloudStub {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.noteBackground.opacity(0),
                                Color.noteBackground.opacity(0.8),
                                Color.noteBackground
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)
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
            .background(isSelected ? Color.accentColor.opacity(Color.lightOpacity) : Color.noteBackground)
            .cornerRadius(cardCornerRadius)
            .shadow(color: Color.cardShadow, radius: shadowRadius, x: 0, y: 2)
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
                                    .fill(Color.noteBackground)
                                    .frame(width: 24, height: 24)
                            )
                    }
                    Spacer()
                }
            }
        }
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
    }
}

struct TagFilterBar: View {
    let availableTags: [Tag]
    @Binding var selectedTags: Set<String>
    @Environment(\.navigationGestureActive) private var navigationGestureActive
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTags.removeAll()
                    }
                }) {
                    TagFilterChipLabel(
                        title: "overview.all_notes".localized,
                        detail: nil,
                        isSelected: selectedTags.isEmpty
                    )
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTags.isEmpty)
                .buttonStyle(TagButtonStyle())
                
                // Tag filter buttons
                ForEach(availableTags) { tag in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedTags.contains(tag.name) {
                                selectedTags.remove(tag.name)
                            } else {
                                selectedTags.insert(tag.name)
                            }
                        }
                    }) {
                        TagFilterChipLabel(
                            title: "tags.hashtag_prefix".localized(tag.name),
                            detail: tag.usageCount > 1 ? String(format: "overview.tag_count".localized, tag.usageCount) : nil,
                            isSelected: selectedTags.contains(tag.name)
                        )
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedTags.contains(tag.name))
                    .buttonStyle(TagButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .horizontalScrollFades(color: Color.appBackground)
        .disabled(navigationGestureActive)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(height: 48) // Adjusted height for consistent layout with smaller shadows
    }
    
}

// MARK: - Custom Button Styles

private struct TagFilterChipLabel: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    
    var body: some View {
        let shape = Capsule(style: .continuous)
        
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.primaryText)
            
            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.primaryText.opacity(0.65))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(shape.fill(Color.tagBackground))
        .overlay(
            shape
                .stroke(isSelected ? Color.accentColor : Color.separator.opacity(0.2), lineWidth: isSelected ? 1.4 : 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .contentShape(shape)
    }
}

struct TagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
