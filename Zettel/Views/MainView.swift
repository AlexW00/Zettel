import SwiftUI
import UIKit
import AppIntents

enum TearDirection {
    case rightward
    case leftward
}

struct MainView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var showSettings = false
    @State private var showArchive = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var tearProgress: CGFloat = 0
    @State private var tearDirection: TearDirection = .rightward
    @State private var showNewNoteConfirmation = false
    
    private let tearThreshold: CGFloat = GestureConstants.tearThreshold
    private let tearZoneHeight: CGFloat = LayoutConstants.Size.tearZoneHeight
    
    var body: some View {
        SwipeNavigationView(showOverview: $showArchive) {
            NavigationStack {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Dismiss keyboard when tapping on background
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    
                    VStack(spacing: 0) {
                        noteCard
                            .frame(maxWidth: 600)
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                            .padding(.bottom, 40)
                        Spacer(minLength: 0)
                            .onTapGesture {
                                // Dismiss keyboard when tapping on spacer area
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Add an invisible toolbar item in the center to capture taps
                    ToolbarItem(placement: .principal) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Dismiss keyboard when tapping on navigation bar center area
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { 
                            // Dismiss keyboard before showing settings
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            showSettings = true 
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 17))
                                .foregroundColor(.primaryText)
                        }
                    }
                    
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            // Dismiss keyboard before sharing
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            shareNote()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17))
                                .foregroundColor(.primaryText)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(noteStore: noteStore)
                }
                .alert(StringConstants.Shortcuts.confirmationTitle.localized, isPresented: $showNewNoteConfirmation) {
                    Button(StringConstants.Actions.cancel.localized, role: .cancel) { }
                    Button(StringConstants.Shortcuts.createNewNote.localized, role: .destructive) {
                        noteStore.createNewNoteFromShortcut()
                    }
                } message: {
                    Text(StringConstants.Shortcuts.confirmationMessage.localized)
                }
            }
        } overviewContent: {
            OverviewGrid(noteStore: noteStore, showArchive: $showArchive)
        }
        .environmentObject(noteStore)
        .onAppear {
            setupNotificationListeners()
        }
        .onChange(of: noteStore.shouldShowMainView) { _, newValue in
            if newValue {
                showArchive = false
                noteStore.shouldShowMainView = false
            }
        }
    }
    
    private var noteCard: some View {
        VStack(spacing: 0) {
            TextField(StringConstants.Note.titlePlaceholder.localized, text: $noteStore.currentNote.title)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.primaryText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 18)
            
            TearEdgeView(
                dragOffset: $dragOffset,
                tearProgress: $tearProgress,
                isDragging: $isDragging,
                tearDirection: $tearDirection,
                onTear: {
                    let screenWidth = UIScreen.main.bounds.width
                    let targetOffset = tearDirection == .rightward ? screenWidth : -screenWidth
                    
                    withAnimation(.easeOut(duration: LayoutConstants.Animation.standard)) {
                        dragOffset = targetOffset
                        tearProgress = 1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + LayoutConstants.Animation.standard) {
                        noteStore.archiveCurrentNote()
                        withAnimation(.easeInOut(duration: LayoutConstants.Animation.quick)) {
                            dragOffset = 0
                            tearProgress = 0
                        }
                    }
                }
            )
                .frame(height: tearZoneHeight)
            
            TaggableTextEditor(
                text: Binding(
                    get: { noteStore.currentNote.content },
                    set: { noteStore.updateCurrentNoteContent($0) }
                ),
                font: UIFont.monospacedSystemFont(ofSize: LayoutConstants.FontSize.large, weight: .regular),
                foregroundColor: .primaryText
            )
            .padding(.horizontal, LayoutConstants.Padding.large)
            .padding(.bottom, LayoutConstants.Padding.large)
            .background(Color.noteBackground)
            .opacity(max(0.25, 1.0 - (tearProgress * ThemeConstants.Opacity.veryHeavy)))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(StringConstants.Actions.done.localized) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    }
                }
        }
        .background(Color.noteBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.cardShadow, radius: 8, x: 0, y: 2)
        .scaleEffect(x: 1 + tearProgress * 0.1, y: 1 - tearProgress * 0.02)
        .offset(x: tearProgress * (tearDirection == .rightward ? 20 : -20))
        .opacity(1 - tearProgress * 0.3)
        .rotation3DEffect(
            .degrees(tearProgress * (tearDirection == .rightward ? 15 : -15)),
            axis: (x: 0, y: 1, z: 0),
            anchor: tearDirection == .rightward ? .leading : .trailing,
            perspective: 0.5
        )
    }
    
    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: .showNewNoteConfirmation,
            object: nil,
            queue: .main
        ) { _ in
            showNewNoteConfirmation = true
        }
    }
    
    private func shareNote() {
        let note = noteStore.currentNote

        // Create formatted content with title and content
        let sharedContent: String
        if !note.title.isEmpty {
            sharedContent = "\(note.title)\n\n\(note.content)"
        } else {
            // Use auto-generated title if no title is set
            sharedContent = "\(note.autoGeneratedTitle)\n\n\(note.content)"
        }

        let activityVC = UIActivityViewController(
            activityItems: [sharedContent],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct TearEdgeView: View {
    @Binding var dragOffset: CGFloat
    @Binding var tearProgress: CGFloat
    @Binding var isDragging: Bool
    @Binding var tearDirection: TearDirection
    let onTear: () -> Void
    
    @State private var dragStartLocation: CGPoint = .zero
    @State private var currentDragLocation: CGPoint = .zero
    @State private var isHovering = false
    @State private var lastHapticProgress: CGFloat = 0
    @State private var allowedDirection: TearDirection = .rightward
    private let tearThreshold: CGFloat = GestureConstants.tearThreshold
    private let minimumDragDistance: CGFloat = GestureConstants.minimumDragDistance
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.noteBackground)
                    .frame(height: geometry.size.height.safeDivide(by: 2, fallback: 20))
                    .frame(maxHeight: .infinity, alignment: .top)

            // Progress line indicator
            ZStack {
                // Dotted line (always visible)
                HStack(spacing: 8) {
                    ForEach(0..<max(0, Int(geometry.size.width.safeDivide(by: 10, fallback: 0))), id: \.self) { _ in
                        Circle()
                            .fill(Color.tearIndicator)
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(width: geometry.size.width.safeCGFloat(), height: 3)
                
                // Progress fill line (only visible when dragging, centered on dotted line)
                if isDragging {
                    HStack {
                        if allowedDirection == .rightward {
                            Rectangle()
                                .fill(tearProgress >= 1 ? Color.tearIndicatorActive : Color.tearIndicator)
                                .frame(height: 2)
                                .frame(width: geometry.size.width * min(1.0, tearProgress))
                                .animation(.easeInOut(duration: 0.15), value: tearProgress)
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(tearProgress >= 1 ? Color.tearIndicatorActive : Color.tearIndicator)
                                .frame(height: 2)
                                .frame(width: geometry.size.width * min(1.0, tearProgress))
                                .animation(.easeInOut(duration: 0.15), value: tearProgress)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: minimumDragDistance)
                .onChanged { value in
                    if !isDragging {
                        dragStartLocation = value.startLocation
                        isDragging = true
                        lastHapticProgress = 0 // Reset haptic tracking when drag starts
                        
                        // Determine allowed direction based on starting location
                        let screenWidth = UIScreen.main.bounds.width
                        let relativeStartX = value.startLocation.x
                        allowedDirection = relativeStartX < screenWidth / 2 ? .rightward : .leftward
                        tearDirection = allowedDirection
                    }
                    
                    currentDragLocation = value.location
                    let translation = value.translation.width
                    
                    // Only respond to drags in the allowed direction
                    let validDrag: Bool
                    let effectiveTranslation: CGFloat
                    
                    if allowedDirection == .rightward {
                        validDrag = translation > 0
                        effectiveTranslation = max(0, translation)
                    } else {
                        validDrag = translation < 0
                        effectiveTranslation = max(0, -translation)
                    }
                    
                    if validDrag && effectiveTranslation > 0 {
                        dragOffset = effectiveTranslation
                        tearProgress = min(1, effectiveTranslation.safeDivide(by: GestureConstants.tearProgressMultiplier, fallback: 0))
                        
                        // Enhanced haptic feedback system
                        let screenWidth = UIScreen.main.bounds.width
                        let dragDistance = effectiveTranslation
                        let widthProgress = min(1.0, dragDistance / screenWidth) // Progress based on screen width
                        
                        let hapticInterval: CGFloat = GestureConstants.hapticInterval // Every 5% of screen width (increased frequency)
                        let currentInterval = floor(widthProgress / hapticInterval)
                        let lastInterval = floor(lastHapticProgress / hapticInterval)
                        
                        if currentInterval > lastInterval && widthProgress > 0.05 {
                            let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
                            mediumFeedback.impactOccurred(intensity: 0.5) // Reduced intensity for subtler bumps
                        }
                        
                        // Update last haptic progress to track screen width progress, not tear progress
                        lastHapticProgress = widthProgress
                    }
                }
                .onEnded { value in
                    let shouldTear = tearProgress >= 1
                    
                    if shouldTear {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        onTear()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                            tearProgress = 0
                        }
                    }
                    
                    isDragging = false
                    dragStartLocation = .zero
                    currentDragLocation = .zero
                    lastHapticProgress = 0 // Reset haptic tracking when drag ends
                }
        )
        .onHover { hovering in
            // Support for iPad with trackpad/mouse
            isHovering = hovering
        }
        .accessibilityLabel(StringConstants.Accessibility.tearZone.localized)
        .accessibilityHint("Swipe horizontally from either side to tear off and archive the current note. Start from left side to tear rightward, start from right side to tear leftward.")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}


#Preview {
    MainView()
        .environmentObject(NoteStore())
        .environmentObject(ThemeStore())
        .environmentObject(LocalizationManager.shared)
}
