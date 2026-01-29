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
                        if backgroundStore.videoLoopFadeDuration > 0 {
                            CrossfadingLoopPlayerView(
                                url: videoURL
                            )
                        } else {
                            LoopingVideoPlayerView(
                                url: videoURL,
                                volume: backgroundStore.videoVolume
                            )
                        }
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
        .onAppear {
            // Configure audio session to mix with other apps (Ambient)
            // This ensures respect for the ringer switch (silent mode)
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to set audio session category: \(error)")
            }
        }
    }
}

/// A view that plays a video in a loop
struct LoopingVideoPlayerView: View {
    let url: URL
    let volume: Double
    
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    
    @Environment(\.scenePhase) private var scenePhase
    
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
        .onChange(of: volume) { newValue in
            player?.volume = Float(newValue)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                player?.play()
            }
        }
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Create looper for seamless looping
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        // Set volume
        queuePlayer.volume = Float(volume)
        queuePlayer.isMuted = false // Controlled by volume
        
        // Start playing
        queuePlayer.play()
        
        self.player = queuePlayer
        self.playerLooper = looper
    }
}

/// UIViewRepresentable wrapper for AVPlayerLayer to enable proper video sizing
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?
    
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

/// A view that plays a video with a crossfade effect at the loop point
struct CrossfadingLoopPlayerView: View {
    let url: URL
    // We use EnvironmentObject to ensure the timeObserver closure captures the reference to the store,
    // allowing it to see real-time updates to volume and fade duration.
    @EnvironmentObject var backgroundStore: BackgroundStore
    
    @State private var player1: AVPlayer?
    @State private var player2: AVPlayer?
    
    @State private var opacity1: Double = 1.0
    @State private var opacity2: Double = 0.0
    
    @State private var duration: Double = 0.0
    @State private var timeObserver: Any?
    
    // Track which player is currently "main" (the one fading out)
    @State private var currentPlayerIndex = 1
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Player 1
                if let p1 = player1 {
                    VideoPlayerLayerView(player: p1)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(opacity1)
                }
                
                // Player 2
                if let p2 = player2 {
                    VideoPlayerLayerView(player: p2)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(opacity2)
                }
            }
        }
        .onAppear {
            setupPlayers()
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: backgroundStore.videoLoopFadeDuration) {
            // Just update the observer logic, don't restart players
            setupTimeObserver()
        }
        .onChange(of: url) {
            // Full restart only if URL changes
            cleanup()
            setupPlayers()
        }
        .onChange(of: backgroundStore.videoVolume) { newValue in
            // Update volumes immediately
            updateVolumes()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Determine which player should be playing
                // Usually both are "ready" but one might be paused if waiting for crossfade
                // But generally, AVPlayer pauses when backgrounded. Resuming primarily the active one is critical.
                // Resuming the background one is also safe if it was in the middle of a crossfade (handled by timeObserver?)
                // Safest approach: Play the active player. The background player's state is managed by the timeObserver,
                // but if we are in a crossfade, the timeObserver loop will tick and ensure things are right.
                // Just calling play() on the players is what's needed.
                
                player1?.play()
                // If we are crossfading, play the second one too just in case it was playing
                // Actually, just playing both is fine because `setupTimeObserver` manages `bg.pause()` if it shouldn't be playing yet.
                // Wait, `setupTimeObserver` only pauses BG at the START of the loop.
                // If we are mid-fade, both should be playing.
                // If we are not fading, BG should be paused (and at zero).
                
                // Let's rely on the fact that if it wasn't playing, playing it might not be skipping logic, 
                // BUT `setupTimeObserver` logic triggers `bg.play()` when fade starts.
                // If we blindly play both, we might start the background player prematurely.
                
                // Correct logic:
                // 1. Play the main active player.
                let activePlayer = (currentPlayerIndex == 1) ? player1 : player2
                activePlayer?.play()
                
                // 2. If we are in the middle of a fade (opacity2 > 0 and opacity1 < 1.0 for example),
                //    or simply if the timeObserver says so... 
                //    Actually, simple check: if the bg player has volume > 0, it should be playing.
                //    Or simpler: just check if it WAS playing before backgrounding? No, we don't store that.
                
                //    Let's check the time.
                if let active = activePlayer {
                     let currentTime = active.currentTime().seconds
                     let fadeDuration = backgroundStore.videoLoopFadeDuration
                     let triggerTime = max(0, duration - fadeDuration)
                     
                     if currentTime >= triggerTime {
                         // We should be in fade, so resume the other one too
                         let bgPlayer = (currentPlayerIndex == 1) ? player2 : player1
                         bgPlayer?.play()
                     }
                }
            }
        }
    }
    
    private func updateVolumes() {
        let vol = backgroundStore.videoVolume
        player1?.volume = Float(vol * opacity1)
        player2?.volume = Float(vol * opacity2)
    }
    
    private func setupPlayers() {
        let asset = AVURLAsset(url: url)
        
        Task {
            do {
                let duration = try await asset.load(.duration).seconds
                await MainActor.run {
                    self.duration = duration
                    
                    // Cleanup existing if any (just in case)
                    self.cleanup()
                    
                    // Initialize players
                    let p1 = AVPlayer(url: url)
                    let p2 = AVPlayer(url: url)
                    
                    p1.isMuted = false
                    p2.isMuted = false
                    
                    // Initial volumes
                    let vol = backgroundStore.videoVolume
                    p1.volume = Float(vol) // opacity1 is 1.0
                    p2.volume = 0.0 // opacity2 is 0.0
                    
                    self.player1 = p1
                    self.player2 = p2
                    
                    // Start first player
                    p1.play()
                    
                    // Reset index
                    self.currentPlayerIndex = 1
                    self.opacity1 = 1.0
                    self.opacity2 = 0.0
                    
                    // Setup time observer on the active player to trigger transitions
                    setupTimeObserver()
                }
            } catch {
                print("Failed to load video duration: \(error)")
            }
        }
    }
    
    private func removeTimeObserverSafe() {
        guard let observer = timeObserver else { return }
        
        // The observer is always attached to the player at currentPlayerIndex
        // We must remove it from that specific player.
        let activePlayer = (currentPlayerIndex == 1) ? player1 : player2
        
        activePlayer?.removeTimeObserver(observer)
        
        timeObserver = nil
    }
    
    private func setupTimeObserver() {
        removeTimeObserverSafe()
        
        let interval = CMTime(value: 1, timescale: 30) // Check 30 times per second
        
        // We observe the "main" player (the one that is currently playing the body of the video)
        let activePlayer = (currentPlayerIndex == 1) ? player1 : player2
        let backgroundPlayer = (currentPlayerIndex == 1) ? player2 : player1
        
        guard let active = activePlayer, let bg = backgroundPlayer else { return }
        
        // Ensure BG player is paused and at start
        bg.pause()
        bg.seek(to: .zero)
        
        // Capture a weak reference to store? No, EnvironmentObject wrapper is safe enough usually, 
        // but to be absolutely safe and ensure we get the LATEST value, we rely on the fact 
        // that 'self' captures the view struct which holds the EnvironmentObject wrapper which holds the reference.
        // However, capturing 'self' in an escaping closure (timeObserver) captures the Struct Value AT WRITING.
        // The EnvironmentObject wrapper inside that struct copy MIGHT still point to the valid object.
        // Standard SwiftUI pattern suggests this works.
        
        timeObserver = active.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let currentTime = time.seconds
            let fadeDuration = backgroundStore.videoLoopFadeDuration
            let triggerTime = max(0, duration - fadeDuration)
            
            if currentTime >= triggerTime {
                // Calculate progress of fade (0.0 to 1.0)
                let fadeProgress = (currentTime - triggerTime) / fadeDuration
                let progress = min(max(fadeProgress, 0.0), 1.0)
                
                // Start background player if not playing
                if bg.rate == 0 {
                    bg.play()
                }
                
                // Update opacities
                if currentPlayerIndex == 1 {
                    opacity1 = 1.0 - progress
                    opacity2 = progress
                } else {
                    opacity2 = 1.0 - progress
                    opacity1 = progress
                }
                
                // Update audio volumes to match fade
                updateVolumes()
                
                // Check if fade complete (or video ended)
                if currentTime >= duration || progress >= 1.0 {
                    // Switch roles
                    flipPlayers()
                }
            } else {
                // Reset opacities to standard state in case of seek/glitch
                if currentPlayerIndex == 1 {
                    opacity1 = 1.0
                    opacity2 = 0.0
                } else {
                    opacity1 = 0.0
                    opacity2 = 1.0
                }
                updateVolumes()
            }
        }
    }
    
    private func flipPlayers() {
        // Remove observer from CURRENT active player before switching index
        removeTimeObserverSafe()
        
        let finishedPlayer = (currentPlayerIndex == 1) ? player1 : player2
        
        // Reset finished player
        finishedPlayer?.pause()
        finishedPlayer?.seek(to: .zero)
        
        // Swap index
        currentPlayerIndex = (currentPlayerIndex == 1) ? 2 : 1
        
        // Ensure opacities are clean
        if currentPlayerIndex == 1 {
            opacity1 = 1.0
            opacity2 = 0.0
        } else {
            opacity1 = 0.0
            opacity2 = 1.0
        }
        
        updateVolumes()
        
        // Setup observer on the NEW active player
        setupTimeObserver()
    }
    
    private func cleanup() {
        removeTimeObserverSafe()
        player1?.pause()
        player2?.pause()
        player1 = nil
        player2 = nil
    }
}
