//
//  TransparentNavigationModifier.swift
//  Zettel
//
//  Makes the underlying UIKit hosting controller background transparent.
//

import SwiftUI

/// A view modifier that makes the underlying hosting controller background transparent
struct TransparentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TransparentBackgroundView())
    }
}

/// A UIViewRepresentable that traverses the view hierarchy to clear backgrounds
struct TransparentBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = TransparentBackgroundUIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Re-apply transparency on updates
        DispatchQueue.main.async {
            uiView.superview?.backgroundColor = .clear
            clearBackgrounds(from: uiView)
        }
    }
    
    private func clearBackgrounds(from view: UIView) {
        // Walk up the view hierarchy and clear backgrounds
        var current: UIView? = view
        while let parent = current?.superview {
            // Clear the background of hosting controllers and navigation-related views
            if parent.backgroundColor != nil && parent.backgroundColor != .clear {
                parent.backgroundColor = .clear
            }
            
            // Also check for specific controller types
            if let vc = parent.next as? UIViewController {
                vc.view.backgroundColor = .clear
            }
            
            current = parent
        }
    }
}

/// Custom UIView that clears its ancestor backgrounds when added to the hierarchy
class TransparentBackgroundUIView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        guard window != nil else { return }
        
        // Clear backgrounds up the hierarchy
        DispatchQueue.main.async { [weak self] in
            self?.clearAncestorBackgrounds()
        }
    }
    
    private func clearAncestorBackgrounds() {
        var current: UIView? = self
        while let parent = current?.superview {
            parent.backgroundColor = .clear
            
            // Also check the view controller
            if let vc = parent.next as? UIViewController {
                vc.view.backgroundColor = .clear
            }
            
            current = parent
        }
    }
}

extension View {
    /// Makes the underlying UIKit hosting controller background transparent
    func transparentBackground() -> some View {
        self.modifier(TransparentBackgroundModifier())
    }
}
