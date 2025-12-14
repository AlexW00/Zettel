//
//  LoadingStateView.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI

struct LoadingStateView: View {
    @State private var isAnimating = false
    let error: Error?
    let retryAction: (() -> Void)?
    
    init(error: Error? = nil, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if let error = error {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        Text(StringConstants.Loading.loadingError.localized)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.primaryText)
                        
                        Text(error.localizedDescription)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let retryAction = retryAction {
                        Button(action: retryAction) {
                            Text(StringConstants.Loading.retryButton.localized)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
            } else {
                // Loading state
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.accentColor, lineWidth: 4)
                        .frame(width: 48, height: 48)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                VStack(spacing: 8) {
                    Text(StringConstants.Loading.loadingNotes.localized)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.primaryText)
                    
                    Text(StringConstants.Loading.loadingSubtitle.localized)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.overviewBackground)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

#Preview {
    LoadingStateView()
        .environmentObject(ThemeStore())
        .environmentObject(LocalizationManager.shared)
}
