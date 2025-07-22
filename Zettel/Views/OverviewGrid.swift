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
    @State private var showTagFilter = false
    
    // Scroll fade effects
    @State private var showTopFade = false

    // Design system constants
    private let cardCornerRadius: CGFloat = 14
    private let shadowRadius: CGFloat = 3
    private let fadeHeight: CGFloat = 24

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
            return noteStore.tagStore.getMostPopularTags(limit: 10)
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
            
            return Array(availableTagObjects.prefix(10))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack(spacing: 0) {
                    // Tag filter bar
                    if !noteStore.tagStore.allTags.isEmpty {
                        TagFilterBar(
                            availableTags: availableTags,
                            selectedTags: $selectedTagFilters
                        )
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .background(Color.overviewBackground)
                    }
                    
                    ZStack {
                        if filteredNotes.isEmpty {
                            // Empty state view
                            EmptyStateView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.overviewBackground)
                        } else {
                            ScrollView {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: gridSpacing(for: geometry.size.width)),
                                        GridItem(.flexible(), spacing: gridSpacing(for: geometry.size.width))
                                    ],
                                    spacing: gridSpacing(for: geometry.size.width)
                                ) {
                                    ForEach(filteredNotes) { note in
                                        NoteCard(note: note, isSelected: selectedNotes.contains(note.filename), isSelectionMode: isSelectionMode)
                                            .frame(height: cardHeight(for: geometry.size.width))
                                            .contextMenu {
                                                if !isSelectionMode {
                                                    Button(role: .destructive) {
                                                        withAnimation(.easeInOut(duration: 0.3)) {
                                                            noteStore.deleteArchivedNote(note)
                                                        }
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                            }
                                            .onTapGesture {
                                                if isSelectionMode {
                                                    toggleNoteSelection(note)
                                                } else {
                                                    noteStore.loadArchivedNoteAsCurrent(note)
                                                    showArchive = false
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 24) // 3x base unit
                                .padding(.top, 20)
                                .animation(.easeInOut(duration: 0.15), value: filteredNotes.count)
                                .background(
                                    GeometryReader { scrollProxy in
                                        Color.clear
                                            .onAppear {
                                                updateScrollFadeVisibility(
                                                    contentFrame: scrollProxy.frame(in: .named("scrollContainer")),
                                                    containerHeight: geometry.size.height
                                                )
                                            }
                                            .onChange(of: scrollProxy.frame(in: .named("scrollContainer"))) { _, frame in
                                                updateScrollFadeVisibility(
                                                    contentFrame: frame,
                                                    containerHeight: geometry.size.height
                                                )
                                            }
                                    }
                                )
                            }
                            .coordinateSpace(name: "scrollContainer")
                            .navigationTitle("")
                            .navigationBarTitleDisplayMode(.inline)
                            .background(Color.overviewBackground)
                        }
                        
                        // Top fade gradient (only show when not in empty state)
                        if showTopFade && !filteredNotes.isEmpty {
                            VStack {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.overviewBackground,
                                        Color.overviewBackground.opacity(0.8),
                                        Color.overviewBackground.opacity(0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: fadeHeight)
                                .allowsHitTesting(false)
                                Spacer()
                            }
                        }
                        
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

                                    Button("Cancel") {
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
                }
                } // VStack
            } // NavigationStack
        } // GeometryReader
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
                    Text(note.content)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondaryText)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // Gradient overlay for overflow indication (hidden in selection mode)
                    if !isSelectionMode {
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
            
            Text("Your saved notes will appear here")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // Ensures the entire area is tappable if needed
    }
}

// MARK: - Scroll Fade Functions

extension OverviewGrid {
    private func updateScrollFadeVisibility(contentFrame: CGRect, containerHeight: CGFloat) {
        // Calculate if content is scrolled beyond natural boundaries
        // Top fade appears when content has scrolled down (negative y offset)
        showTopFade = contentFrame.minY < -5
    }
}


// MARK: - Selection Actions Extension

extension OverviewGrid {
    private func deleteNote(_ note: Note) {
        withAnimation(.easeInOut(duration: 0.3)) {
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
    @State private var showTrailingFade = false
    @State private var showLeadingFade = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ScrollViewReader { reader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // "All" button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTags.removeAll()
                                }
                            }) {
                                Text("overview.all_notes".localized)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTags.isEmpty ? .white : .primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTags.isEmpty ? Color.accentColor : Color.noteBackground)
                                    .cornerRadius(16)
                                    .scaleEffect(selectedTags.isEmpty ? 1.05 : 1.0)
                                    .shadow(color: selectedTags.isEmpty ? Color.accentColor.opacity(Color.mediumOpacity) : Color.clear, 
                                           radius: selectedTags.isEmpty ? 4 : 0, x: 0, y: 2)
                            }
                            .animation(.easeInOut(duration: 0.25), value: selectedTags.isEmpty)
                            .buttonStyle(TagButtonStyle())
                            .id("allButton")
                            
                            // Tag filter buttons
                            ForEach(availableTags) { tag in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if selectedTags.contains(tag.name) {
                                            selectedTags.remove(tag.name)
                                        } else {
                                            selectedTags.insert(tag.name)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text("#\(tag.name)")
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        
                                        if tag.usageCount > 1 {
                                            Text("(\(tag.usageCount))")
                                                .font(.system(size: 12, weight: .regular))
                                                .opacity(0.7)
                                        }
                                    }
                                    .foregroundColor(selectedTags.contains(tag.name) ? .white : .primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTags.contains(tag.name) ? Color.accentColor : Color.noteBackground)
                                    .cornerRadius(16)
                                    .scaleEffect(selectedTags.contains(tag.name) ? 1.05 : 1.0)
                                    .shadow(color: selectedTags.contains(tag.name) ? Color.accentColor.opacity(Color.mediumOpacity) : Color.clear, 
                                           radius: selectedTags.contains(tag.name) ? 4 : 0, x: 0, y: 2)
                                }
                                .animation(.easeInOut(duration: 0.25), value: selectedTags.contains(tag.name))
                                .buttonStyle(TagButtonStyle())
                                .id("tag_\(tag.name)")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            GeometryReader { scrollProxy in
                                Color.clear
                                    .onAppear {
                                        checkForOverflow(contentWidth: scrollProxy.size.width, containerWidth: geometry.size.width)
                                    }
                                    .onChange(of: availableTags) { _, _ in
                                        checkForOverflow(contentWidth: scrollProxy.size.width, containerWidth: geometry.size.width)
                                    }
                                    .onChange(of: scrollProxy.frame(in: .named("scrollContainer")).origin.x) { _, offset in
                                        updateFadeVisibility(scrollOffset: offset)
                                    }
                            }
                        )
                    }
                    .coordinateSpace(name: "scrollContainer")
                }
                
                // Leading fade gradient
                if showLeadingFade {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.overviewBackground,
                            Color.overviewBackground.opacity(0.8),
                            Color.overviewBackground.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 24)
                    .allowsHitTesting(false)
                }
                
                // Trailing fade gradient
                if showTrailingFade {
                    HStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.overviewBackground.opacity(0),
                                Color.overviewBackground.opacity(0.8),
                                Color.overviewBackground
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 24)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: 56) // Increased height to accommodate button shadows and bloom effects
    }
    
    private func checkForOverflow(contentWidth: CGFloat, containerWidth: CGFloat) {
        showTrailingFade = contentWidth > containerWidth
    }
    
    private func updateFadeVisibility(scrollOffset: CGFloat) {
        // Show leading fade when scrolled to the right
        // When scrolled right, the content moves left, so the origin.x becomes negative
        showLeadingFade = scrollOffset < -5
    }
}

// MARK: - Custom Button Styles

struct TagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
