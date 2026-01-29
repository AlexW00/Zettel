//
//  BackgroundMediaView.swift
//  Zettel
//
//  Displays the custom background image or video.
//

import SwiftUI
import AVKit

/// View that renders the custom background image or video
struct BackgroundMediaView: View {
    @EnvironmentObject private var backgroundStore: BackgroundStore
    @EnvironmentObject private var themeStore: ThemeStore
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch backgroundStore.backgroundType {
                case .none:
                    // Default app background
                    Color.appBackground
                    
                case .image:
                    if let image = backgroundStore.backgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        Color.appBackground
                    }
                    
                case .video:
                    if let videoURL = backgroundStore.backgroundVideoURL {
                        LoopingVideoPlayerView(url: videoURL)
                    } else {
                        Color.appBackground
                    }
                }
                
                // Dimming overlay
                if backgroundStore.hasCustomBackground {
                    Color(UIColor.systemBackground)
                        .opacity(backgroundStore.backgroundDimming)
                        .allowsHitTesting(false) // Allow interactions to pass through if needed, though this is background
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

/// A view that plays a video in a loop, muted
struct LoopingVideoPlayerView: View {
    let url: URL
    
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    
    var body: some View {
        GeometryReader { geometry in
            VideoPlayerLayerView(player: player)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            playerLooper = nil
        }
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Create looper for seamless looping
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        // Mute the video
        queuePlayer.isMuted = true
        
        // Start playing
        queuePlayer.play()
        
        self.player = queuePlayer
        self.playerLooper = looper
    }
}

/// UIViewRepresentable wrapper for AVPlayerLayer to enable proper video sizing
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVQueuePlayer?
    
    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

/// Custom UIView that uses AVPlayerLayer as its backing layer
class PlayerLayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

#Preview {
    BackgroundMediaView()
        .environmentObject(BackgroundStore())
        .environmentObject(ThemeStore())
}
