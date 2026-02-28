//
//  TagAutocompletePanel.swift
//  ZettelMac
//
//  Floating Liquid Glass panel shown below the cursor while the user types
//  a hashtag.  Cycle with Tab / Shift+Tab, confirm with Return, dismiss with
//  Escape or by clicking anywhere else.
//

import AppKit
import SwiftUI

// MARK: - Suggestion State

private let maxVisibleRows = 5

/// Observable state shared between the coordinator and the SwiftUI suggestion view.
final class TagSuggestionState: ObservableObject {
    @Published var suggestions: [String] = []
    @Published var selectedIndex: Int = 0
    /// 1 = navigating forward/down, -1 = navigating backward/up (drives barrel-roll direction).
    @Published var navigationDirection: Int = 1
    var onSelect: ((String) -> Void)?

    /// Index clamped to valid suggestion bounds (safe for access).
    var clampedIndex: Int {
        guard !suggestions.isEmpty else { return 0 }
        return min(max(selectedIndex, 0), suggestions.count - 1)
    }

    /// Reset all state to defaults. Use when hiding the panel to prevent stale
    /// values from leaking into the next show cycle.
    func reset() {
        suggestions = []
        selectedIndex = 0
        navigationDirection = 1
        onSelect = nil
    }
}

// MARK: - SwiftUI Suggestion View

/// Liquid Glass suggestion list rendered inside the floating panel.
struct TagSuggestionsView: View {
    @ObservedObject var state: TagSuggestionState

    /// The window of suggestion indices currently on screen (at most `maxVisibleRows` items).
    private var visibleRange: Range<Int> {
        let total = state.suggestions.count
        guard total > 0 else { return 0..<0 }
        guard total > maxVisibleRows else { return 0..<total }
        let half = maxVisibleRows / 2
        let idx = state.clampedIndex
        let start = max(0, min(idx - half, total - maxVisibleRows))
        return start..<(start + maxVisibleRows)
    }

    private var hiddenAbove: Int { visibleRange.lowerBound }
    private var hiddenBelow: Int { state.suggestions.count - visibleRange.upperBound }

    var body: some View {
        // Compute barrel-roll offsets from the current navigation direction so that
        // new items roll in from the direction of travel and old items exit the other way.
        let insertionY: CGFloat = state.navigationDirection == 1 ? 20 : -20
        let removalY:   CGFloat = state.navigationDirection == 1 ? -20 : 20

        VStack(alignment: .leading, spacing: 0) {
            if hiddenAbove > 0 {
                PaginationIndicator(label: "↑  \(hiddenAbove) more")
                Divider().padding(.horizontal, 8)
            }

            ForEach(Array(visibleRange), id: \.self) { globalIndex in
                let tag = state.suggestions[globalIndex]

                TagSuggestionRow(
                    tag: tag,
                    isSelected: globalIndex == state.clampedIndex
                )
                .contentShape(Rectangle())
                .onTapGesture { state.onSelect?(tag) }
                // Transitions only animate when wrapped in an explicit withAnimation
                // (called by selectNext/selectPrevious). Structural changes from show()
                // are not wrapped, so they appear instantly without any scroll-from-
                // stale-position artifact.
                .transition(.asymmetric(
                    insertion: .offset(y: insertionY).combined(with: .opacity),
                    removal:   .offset(y: removalY  ).combined(with: .opacity)
                ))

                if globalIndex < visibleRange.upperBound - 1 {
                    Divider().padding(.horizontal, 8)
                }
            }

            if hiddenBelow > 0 {
                Divider().padding(.horizontal, 8)
                PaginationIndicator(label: "↓  \(hiddenBelow) more")
            }
        }
        .padding(.vertical, 4)
        .glassEffect(in: .rect(cornerRadius: 10))
        // No SwiftUI shadow — NSHostingView clips it to a hard rect.
        // p.hasShadow = true on the NSPanel gives the correct shaped shadow.
    }
}

private struct PaginationIndicator: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
    }
}

private struct TagSuggestionRow: View {
    let tag: String
    let isSelected: Bool
    var onHoverChanged: ((Bool) -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("#")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(tag)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
        }
        .onHover { hovering in
            isHovered = hovering
            onHoverChanged?(hovering)
        }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Controller

/// Manages the floating `NSPanel` that hosts `TagSuggestionsView`.
final class TagAutocompleteController {

    // MARK: State

    private let state = TagSuggestionState()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<TagSuggestionsView>?
    private var clickMonitor: Any?
    private var scrollMonitor: Any?
    private var resignObserver: (any NSObjectProtocol)?
    private var scrollAccumulator: CGFloat = 0
    private static let scrollThreshold: CGFloat = 20

    // MARK: - Lifecycle

    init() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    deinit {
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// The currently highlighted suggestion (nil when panel is hidden).
    var selectedSuggestion: String? {
        guard isVisible, !state.suggestions.isEmpty else { return nil }
        return state.suggestions[safe: state.clampedIndex]
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Show / Update / Hide

    /// Show or refresh the panel anchored below `screenRect` (screen coords).
    func show(suggestions: [String], near screenRect: NSRect, onSelect: @escaping (String) -> Void) {
        guard !suggestions.isEmpty else { hide(); return }

        // Reset state without animation so the panel doesn't visually scroll
        // from a stale position when reopening.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            state.suggestions = suggestions
            state.selectedIndex = 0
            state.navigationDirection = 1
        }
        state.onSelect = onSelect

        let panel = panel ?? makePanel()
        self.panel = panel

        // Force a synchronous layout pass so fittingSize reflects the new
        // suggestions, not the stale content from the previous session.
        if let hostingView = hostingView {
            hostingView.layout()
            let fittingHeight = hostingView.fittingSize.height
            let panelWidth: CGFloat = 220
            panel.setContentSize(CGSize(width: panelWidth, height: fittingHeight))
        }

        // Position: horizontally aligned with cursor, vertically just below
        let originX = screenRect.minX
        let originY = screenRect.minY - panel.frame.height - 4
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        panel.orderFront(nil)
        installClickMonitor()
        installScrollMonitor()
    }

    /// Update suggestions without repositioning.
    func update(suggestions: [String]) {
        guard isVisible else { return }
        guard !suggestions.isEmpty else { hide(); return }

        // Atomically update suggestions and reset index without animation
        // to avoid the view evaluating with a stale selectedIndex against
        // the new (potentially shorter) suggestions array.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            state.suggestions = suggestions
            state.selectedIndex = 0
            state.navigationDirection = 1
        }

        if let hostingView = hostingView, let panel = panel {
            let fittingHeight = hostingView.fittingSize.height
            var frame = panel.frame
            let topAnchorY = frame.maxY   // anchor the top of the panel
            frame.size.height = fittingHeight
            frame.origin.y = topAnchorY - fittingHeight
            panel.setFrame(frame, display: true)
        }
    }

    func selectNext() {
        guard !state.suggestions.isEmpty else { return }
        let clamped = state.clampedIndex
        guard clamped < state.suggestions.count - 1 else { return }
        withAnimation(.spring(duration: 0.22, bounce: 0.15)) {
            state.navigationDirection = 1
            state.selectedIndex = clamped + 1
        }
    }

    func selectPrevious() {
        guard !state.suggestions.isEmpty else { return }
        let clamped = state.clampedIndex
        guard clamped > 0 else { return }
        withAnimation(.spring(duration: 0.15, bounce: 0.1)) {
            state.navigationDirection = -1
            state.selectedIndex = clamped - 1
        }
    }

    func hide() {
        panel?.orderOut(nil)
        removeClickMonitor()
        removeScrollMonitor()
        scrollAccumulator = 0
        state.reset()
    }

    // MARK: - Private

    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            // Hide if the click is outside the panel's frame (screen coords)
            let clickLocation = event.locationInWindow
            let screenPoint: NSPoint
            if let win = event.window {
                screenPoint = win.convertPoint(toScreen: clickLocation)
            } else {
                screenPoint = clickLocation
            }
            if !panel.frame.contains(screenPoint) {
                self.hide()
            }
            return event
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func installScrollMonitor() {
        removeScrollMonitor()
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            // Only intercept scroll events whose window is the panel or are over the panel
            let screenPoint: NSPoint
            if let win = event.window {
                screenPoint = win.convertPoint(toScreen: event.locationInWindow)
            } else {
                screenPoint = event.locationInWindow
            }
            guard panel.frame.contains(screenPoint) else { return event }
            // Accumulate delta and only step when threshold is crossed,
            // preventing a single trackpad swipe from jumping many rows.
            self.scrollAccumulator += event.scrollingDeltaY
            while self.scrollAccumulator >= TagAutocompleteController.scrollThreshold {
                self.selectPrevious()
                self.scrollAccumulator -= TagAutocompleteController.scrollThreshold
            }
            while self.scrollAccumulator <= -TagAutocompleteController.scrollThreshold {
                self.selectNext()
                self.scrollAccumulator += TagAutocompleteController.scrollThreshold
            }
            return nil  // consume the event
        }
    }

    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private func makePanel() -> NSPanel {
        let view = TagSuggestionsView(state: state)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.minSize]
        self.hostingView = hosting

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 100),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true    // system shadow follows the actual visual shape
        p.contentView = hosting
        return p
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
