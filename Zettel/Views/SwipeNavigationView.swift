//
//  SwipeNavigationView.swift
//  Zettel
//
//  Created by Claude on 24.06.25.
//

import SwiftUI

struct SwipeNavigationView<MainContent: View, OverviewContent: View>: View {
    @Binding var showOverview: Bool
    let mainContent: MainContent
    let overviewContent: OverviewContent
    
    @State private var dragOffset: CGFloat = 0
    @State private var previousDragOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    init(showOverview: Binding<Bool>,
         @ViewBuilder mainContent: () -> MainContent,
         @ViewBuilder overviewContent: () -> OverviewContent) {
        self._showOverview = showOverview
        self.mainContent = mainContent()
        self.overviewContent = overviewContent()
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                mainContent
                    .frame(width: geometry.size.width)
                
                overviewContent
                    .frame(width: geometry.size.width)
            }
            .offset(x: showOverview ? -geometry.size.width + dragOffset : dragOffset)
            .gesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let translation = value.translation.width
                        
                        if showOverview {
                            // When overview is shown, only allow dragging right (to go back)
                            if translation > 0 {
                                dragOffset = translation
                            }
                        } else {
                            // When main view is shown, only allow dragging left (to show overview)
                            if translation < 0 {
                                dragOffset = translation
                            }
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width - translation
                        let threshold = geometry.size.width.safeMultiply(by: 0.3, fallback: 100)
                        let velocityThreshold: CGFloat = 500
                        
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if showOverview {
                                // Decide whether to stay on overview or go back to main
                                if translation > threshold || velocity > velocityThreshold {
                                    showOverview = false
                                }
                            } else {
                                // Decide whether to show overview or stay on main
                                if -translation > threshold || -velocity > velocityThreshold {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    showOverview = true
                                }
                            }
                            dragOffset = 0
                        }
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showOverview)
            .onChange(of: showOverview) { _, newValue in
                if newValue {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Reset drag offset when app becomes active to prevent stuck states
                if newPhase == .active {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
            }
            .onChange(of: isDragging) { _, dragging in
                // If drag gesture is cancelled (e.g., by app backgrounding), reset offset
                if !dragging && dragOffset != 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
        }
    }
}
