//
//  BackgroundStore.swift
//  Zettel
//
//  Manages custom background image/video state and persistence.
//

import SwiftUI
import PhotosUI
import AVFoundation

/// Represents the type of custom background
enum BackgroundType: String, Codable {
    case none
    case image
    case video
}

/// Manages the custom background state for the app
@MainActor
class BackgroundStore: ObservableObject {
    /// Current background type
    @Published private(set) var backgroundType: BackgroundType = .none
    
    /// The selected PhotosPicker item (used for binding)
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            if let item = selectedItem {
                Task {
                    await loadMedia(from: item)
                }
            }
        }
    }
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// The loaded UIImage for image backgrounds
    @Published private(set) var backgroundImage: UIImage?
    
    /// The URL for video backgrounds (stored in documents directory)
    @Published private(set) var backgroundVideoURL: URL?
    
    /// Maximum video duration in seconds (10 minutes)
    private let maxVideoDuration: TimeInterval = 10 * 60
    
    /// UserDefaults key for background type
    private let backgroundTypeKey = "backgroundType"
    
    /// File names for stored media
    private let imageFileName = "custom_background.jpg"
    private let videoFileName = "custom_background.mp4"
    
    /// Whether a custom background is set
    var hasCustomBackground: Bool {
        backgroundType != .none
    }
    
    init() {
        loadSavedBackground()
    }
    
    // MARK: - Public Methods
    
    /// Removes the current background
    func removeBackground() {
        // Delete stored files
        deleteStoredMedia()
        
        // Reset state
        backgroundType = .none
        backgroundImage = nil
        backgroundVideoURL = nil
        selectedItem = nil
        
        // Save to UserDefaults
        UserDefaults.standard.set(BackgroundType.none.rawValue, forKey: backgroundTypeKey)
    }
    
    // MARK: - Private Methods
    
    private func loadSavedBackground() {
        guard let savedType = UserDefaults.standard.string(forKey: backgroundTypeKey),
              let type = BackgroundType(rawValue: savedType) else {
            return
        }
        
        backgroundType = type
        
        switch type {
        case .none:
            break
        case .image:
            loadStoredImage()
        case .video:
            loadStoredVideo()
        }
    }
    
    private func loadStoredImage() {
        let url = getDocumentsDirectory().appendingPathComponent(imageFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // File doesn't exist, reset to none
            removeBackground()
            return
        }
        
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            backgroundImage = image
        } else {
            removeBackground()
        }
    }
    
    private func loadStoredVideo() {
        let url = getDocumentsDirectory().appendingPathComponent(videoFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // File doesn't exist, reset to none
            removeBackground()
            return
        }
        
        backgroundVideoURL = url
    }
    
    private func loadMedia(from item: PhotosPickerItem) async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        // Check if it's a video
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            await loadVideo(from: item)
        } else {
            await loadImage(from: item)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image data"
                return
            }
            
            guard let image = UIImage(data: data) else {
                errorMessage = "Invalid image format"
                return
            }
            
            // Save to documents directory (as JPEG to reduce size)
            let url = getDocumentsDirectory().appendingPathComponent(imageFileName)
            
            // Compress to JPEG with reasonable quality
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                errorMessage = "Failed to compress image"
                return
            }
            
            try jpegData.write(to: url)
            
            // Update state
            deleteStoredVideo() // Remove any existing video
            backgroundType = .image
            backgroundImage = image
            backgroundVideoURL = nil
            
            // Save type to UserDefaults
            UserDefaults.standard.set(BackgroundType.image.rawValue, forKey: backgroundTypeKey)
            
        } catch {
            errorMessage = "Failed to save image: \(error.localizedDescription)"
        }
    }
    
    private func loadVideo(from item: PhotosPickerItem) async {
        do {
            // Load video as transferable Movie
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                errorMessage = "Failed to load video"
                return
            }
            
            let sourceURL = movie.url
            
            // Validate video duration
            let asset = AVURLAsset(url: sourceURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            if durationSeconds > maxVideoDuration {
                errorMessage = "settings.video_too_long".localized
                return
            }
            
            // Copy to documents directory
            let destURL = getDocumentsDirectory().appendingPathComponent(videoFileName)
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            
            // Update state
            deleteStoredImage() // Remove any existing image
            backgroundType = .video
            backgroundImage = nil
            backgroundVideoURL = destURL
            
            // Save type to UserDefaults
            UserDefaults.standard.set(BackgroundType.video.rawValue, forKey: backgroundTypeKey)
            
        } catch {
            errorMessage = "Failed to save video: \(error.localizedDescription)"
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func deleteStoredMedia() {
        deleteStoredImage()
        deleteStoredVideo()
    }
    
    private func deleteStoredImage() {
        let url = getDocumentsDirectory().appendingPathComponent(imageFileName)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func deleteStoredVideo() {
        let url = getDocumentsDirectory().appendingPathComponent(videoFileName)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Video Transferable

/// Helper struct for transferring video from PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to a temporary location that we control
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return VideoTransferable(url: tempURL)
        }
    }
}
