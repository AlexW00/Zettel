import SwiftUI
import UIKit

private enum NavigationDragDirection {
    case toOverview
    case toMain
}

struct SwipeNavigationView<MainContent: View, OverviewContent: View>: View {
    @Binding var showOverview: Bool
    let mainContent: MainContent
    let overviewContent: OverviewContent

    @State private var dragOffset: CGFloat = 0
    @State private var activeDirection: NavigationDragDirection?
    @Environment(\.scenePhase) private var scenePhase

    private let activationDistance: CGFloat = 12
    private let completionRatio: CGFloat = 0.28
    private let velocityThreshold: CGFloat = 520
    private let verticalDominanceFactor: CGFloat = 1.15

    init(showOverview: Binding<Bool>,
         @ViewBuilder mainContent: () -> MainContent,
         @ViewBuilder overviewContent: () -> OverviewContent) {
        self._showOverview = showOverview
        self.mainContent = mainContent()
        self.overviewContent = overviewContent()
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = max(1, geometry.size.width)
            let navigationDrag = DragGesture(minimumDistance: activationDistance, coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value: value, containerWidth: containerWidth)
                }
                .onEnded { value in
                    handleDragEnded(value: value, containerWidth: containerWidth)
                }

            HStack(spacing: 0) {
                mainContent
                    .frame(width: containerWidth)

                overviewContent
                    .frame(width: containerWidth)
            }
            .contentShape(Rectangle())
            .offset(x: contentOffset(for: containerWidth))
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showOverview)
            .simultaneousGesture(navigationDrag, including: .all)
            .onChange(of: showOverview) { _, _ in
                resetDragState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    resetDragState(animated: true)
                }
            }
        }
    }

    private func contentOffset(for width: CGFloat) -> CGFloat {
        let base = showOverview ? -width : 0
        return base + dragOffset
    }

    private func handleDragChanged(value: DragGesture.Value, containerWidth: CGFloat) {
        let translation = value.translation
        let absX = abs(translation.width)
        let absY = abs(translation.height)

        if activeDirection == nil {
            guard absX > activationDistance || absY > activationDistance else {
                dragOffset = 0
                return
            }

            // If the drag is mostly vertical, ignore it completely and allow subviews to handle it.
            if absY > absX * verticalDominanceFactor {
                resetDragState()
                return
            }

            if translation.width < 0, !showOverview {
                activeDirection = .toOverview
            } else if translation.width > 0, showOverview {
                activeDirection = .toMain
            } else {
                resetDragState()
                return
            }
        }

        guard let direction = activeDirection else {
            dragOffset = 0
            return
        }

        switch direction {
        case .toOverview:
            dragOffset = max(-containerWidth, min(0, translation.width))
        case .toMain:
            dragOffset = min(containerWidth, max(0, translation.width))
        }
    }

    private func handleDragEnded(value: DragGesture.Value, containerWidth: CGFloat) {
        guard let direction = activeDirection else {
            resetDragState(animated: true)
            return
        }

        let translation = value.translation.width
        let predicted = value.predictedEndTranslation.width
        let velocity = predicted - translation
        let distanceThreshold = containerWidth * completionRatio

        let shouldNavigate: Bool
        let targetShowsOverview = direction == .toOverview

        switch direction {
        case .toOverview:
            let travel = -translation
            shouldNavigate = travel > distanceThreshold || velocity < -velocityThreshold
        case .toMain:
            let travel = translation
            shouldNavigate = travel > distanceThreshold || velocity > velocityThreshold
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if shouldNavigate {
                if targetShowsOverview {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                showOverview = targetShowsOverview
            }
            dragOffset = 0
        }

        activeDirection = nil
    }

    private func resetDragState(animated: Bool = false) {
        let resetAction = {
            dragOffset = 0
            activeDirection = nil
        }

        if animated {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                resetAction()
            }
        } else {
            resetAction()
        }
    }
}
