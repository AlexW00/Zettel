import SwiftUI
import UIKit
import AppIntents

enum TearDirection {
    case rightward
    case leftward
}

struct MainView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var showSettings = false
    @State private var showArchive = false
    @State private var dragOffset: CGFloat = 0
    @State private var animatedOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var tearProgress: CGFloat = 0
    @State private var animatedTearProgress: CGFloat = 0
    @State private var tearDirection: TearDirection = .rightward
    @State private var showNewNoteConfirmation = false
    @State private var lastHapticStep: Int = 0
    
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
            
            TearIndicatorView(
                tearProgress: $tearProgress,
                isDragging: $isDragging
            )
            .frame(height: tearZoneHeight)
            
            TaggableTextEditor(
                text: Binding(
                    get: { noteStore.currentNote.content },
                    set: { noteStore.updateCurrentNoteContent($0) }
                ),
                font: UIFont.monospacedSystemFont(ofSize: themeStore.contentFontSize, weight: .regular),
                foregroundColor: .primaryText
            )
            .padding(.horizontal, LayoutConstants.Padding.large)
            .padding(.bottom, LayoutConstants.Padding.large)
            .background(Color.noteBackground)
            .opacity(max(0.25, 1.0 - ((isDragging ? tearProgress : animatedTearProgress) * ThemeConstants.Opacity.veryHeavy)))
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
        .scaleEffect(x: 1 + (isDragging ? tearProgress : animatedTearProgress) * 0.1, y: 1 - (isDragging ? tearProgress : animatedTearProgress) * 0.02)
        .offset(x: (isDragging ? dragOffset * 0.1 : animatedOffset) + (isDragging ? tearProgress : animatedTearProgress) * 20)
        .opacity(1 - (isDragging ? tearProgress : animatedTearProgress) * 0.3)
        .rotation3DEffect(
            .degrees((isDragging ? tearProgress : animatedTearProgress) * 15),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.5
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: GestureConstants.minimumDragDistance)
                .onChanged { value in
                    let translation = value.translation.width
                    
                    // Only respond to left-to-right swipes (positive translation)
                    if translation > 0 {
                        if !isDragging {
                            isDragging = true
                            tearDirection = .rightward
                            lastHapticStep = 0
                        }
                        
                        dragOffset = translation
                        tearProgress = min(1, translation / GestureConstants.tearProgressMultiplier)
                        
                        // Simplified haptic feedback system using steps
                        let hapticStep = Int(tearProgress * 10) // 10 steps from 0 to 1
                        
                        if hapticStep > lastHapticStep && hapticStep > 0 {
                            let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
                            mediumFeedback.impactOccurred(intensity: 0.5)
                            lastHapticStep = hapticStep
                        }
                    }
                }
                .onEnded { value in
                    let translation = value.translation.width
                    let shouldTear = translation > 0 && tearProgress >= GestureConstants.tearThreshold
                    
                    // Reset haptic step but keep isDragging for animation
                    lastHapticStep = 0
                    
                    if shouldTear {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        
                        // Animate the note back to its original state over 0.3 seconds
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                            tearProgress = 0
                        }
                        
                        // Reset dragging state and archive after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isDragging = false
                            noteStore.archiveCurrentNote()
                        }
                    } else {
                        // Use a single animation for all reset values
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            dragOffset = 0
                            tearProgress = 0
                        }
                        
                        // Reset dragging state after short animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isDragging = false
                        }
                    }
                }
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

struct TearIndicatorView: View {
    @Binding var tearProgress: CGFloat
    @Binding var isDragging: Bool
    
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
                    
                    // Progress fill line (only visible when dragging)
                    if isDragging {
                        HStack {
                            Rectangle()
                                .fill(tearProgress >= 1 ? Color.tearIndicatorActive : Color.tearIndicator)
                                .frame(height: 2)
                                .frame(width: geometry.size.width * min(1.0, tearProgress))
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel(StringConstants.Accessibility.tearZone.localized)
        .accessibilityHint("Swipe left to right anywhere on the note to tear off and archive it.")
    }
}


#Preview {
    MainView()
        .environmentObject(NoteStore())
        .environmentObject(ThemeStore())
        .environmentObject(LocalizationManager.shared)
}
