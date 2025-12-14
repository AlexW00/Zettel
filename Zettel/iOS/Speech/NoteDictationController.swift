//
//  NoteDictationController.swift
//  Zettel
//
//  Created by Codex on 19.10.25.
//
//  Coordinates speech dictation for the note editor using the iOS 26 Speech SDK.
//

import AVFoundation
import AVFAudio
import Combine
import Foundation
import OSLog
@preconcurrency import Speech

@MainActor
final class NoteDictationController: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case recording
        case finishing
        case failed
    }

    enum DictationError: LocalizedError, Identifiable {
        case microphonePermissionDenied
        case localeAssetsMissing
        case analyzerUnavailable
        case transcriptionFailed(String)
        case downloadFailed(String)

        var id: String {
            switch self {
            case .microphonePermissionDenied: return "microphonePermissionDenied"
            case .localeAssetsMissing: return "localeAssetsMissing"
            case .analyzerUnavailable: return "analyzerUnavailable"
            case .transcriptionFailed(let message): return "transcriptionFailed_\(message)"
            case .downloadFailed(let message): return "downloadFailed_\(message)"
            }
        }

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return StringConstants.Dictation.permissionDeniedTitle.localized
            case .localeAssetsMissing:
                return StringConstants.Dictation.localeMissingTitle.localized
            case .analyzerUnavailable:
                return StringConstants.Dictation.analyzerUnavailableTitle.localized
            case .transcriptionFailed:
                return StringConstants.Dictation.transcriptionFailedTitle.localized
            case .downloadFailed:
                return StringConstants.Dictation.downloadFailedTitle.localized
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .microphonePermissionDenied:
                return StringConstants.Dictation.permissionDeniedMessage.localized
            case .localeAssetsMissing:
                return StringConstants.Dictation.localeMissingMessage.localized
            case .analyzerUnavailable:
                return StringConstants.Dictation.analyzerUnavailableMessage.localized
            case .transcriptionFailed(let message):
                return message
            case .downloadFailed(let message):
                return message
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var highlightedRange: NSRange?
    @Published private(set) var isDownloadingLocale = false
    @Published private(set) var downloadProgress: Double = 0
    @Published var activeError: DictationError?
    @Published private(set) var localeInUse: Locale?

    var isDictationRunning: Bool {
        state == .recording || state == .preparing || state == .finishing
    }

    private weak var noteStore: NoteStore?

    private let localeManager: DictationLocaleManager
    private let logger = Logger(subsystem: "com.zettel.note", category: "Dictation")
    nonisolated private static let audioLogger = Logger(subsystem: "com.zettel.note", category: "Dictation.Audio")
    private static let preferredPresets: [DictationTranscriber.Preset] = [
        DictationTranscriber.Preset(
            contentHints: [],
            transcriptionOptions: [.punctuation],
            reportingOptions: [.volatileResults, .frequentFinalization],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        ),
        DictationTranscriber.Preset(
            contentHints: [],
            transcriptionOptions: [.punctuation],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        ),
        DictationTranscriber.Preset(
            contentHints: [.shortForm],
            transcriptionOptions: [.punctuation],
            reportingOptions: [.frequentFinalization],
            attributeOptions: [.audioTimeRange]
        ),
        DictationTranscriber.Preset(
            contentHints: [],
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
    ]

    // Speech pipeline
    private var micCapturer: MicAudioCapturer?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var analyzerInputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerInputTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Error>?
    private var reservedLocale: Locale?
    private var captureFormat: AVAudioFormat?

    // Text handling
    private var baseContent: String = ""
    private var committedTranscription: String = ""
    private var interimTranscription: String = ""
    private var startLocationUTF16: Int = 0

    init(localeManager: DictationLocaleManager? = nil) {
        self.localeManager = localeManager ?? DictationLocaleManager.shared
    }

    func attach(noteStore: NoteStore) {
        self.noteStore = noteStore
    }

    func detachNoteStore() {
        noteStore = nil
    }

    // MARK: - Locale asset management

    @discardableResult
    func ensureLocaleInstalled(_ locale: Locale) async -> Bool {
        await localeManager.refreshInstalledLocales()
        let needsDownload = localeManager.localeRequiresDownload(locale)

        let candidate = await resolveModuleForDownload(locale: locale)
        if let candidate {
            if candidate.status == .installed {
                localeManager.markLocaleInstalled(locale)
                return true
            }
        } else {
            // No compatible module, nothing to install
        }
        let success = await downloadLocaleAssets(locale)
        await localeManager.refreshInstalledLocales()
        let remaining = localeManager.localeRequiresDownload(locale)
        if success && !remaining {
            return true
        }
        return false
    }

    private func downloadLocaleAssets(_ locale: Locale) async -> Bool {
        guard !isDownloadingLocale else {
            logger.debug("Locale asset download already in progress for \(locale.identifier, privacy: .public)")
            return false
        }
        isDownloadingLocale = true
        downloadProgress = 0
        var success = false
        defer {
            self.isDownloadingLocale = false
        }

        do {
            guard let candidate = await resolveModuleForDownload(locale: locale) else {
                let displayName = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
                let message = String(format: StringConstants.Dictation.localeUnsupportedMessage.localized, displayName)
                activeError = .downloadFailed(message)
                return false
            }

            switch candidate.status {
            case .installed:
                await localeManager.refreshInstalledLocales()
                downloadProgress = 1
                return true
            case .supported, .downloading:
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [candidate.module]) {
                    try await request.downloadAndInstall()
                } else {
                    // No request available
                }
                await localeManager.refreshInstalledLocales()
                downloadProgress = 1
                success = true
            case .unsupported:
                // This case should be filtered by resolveModuleForDownload, but handle defensively.
                let displayName = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
                let message = String(format: StringConstants.Dictation.localeUnsupportedMessage.localized, displayName)
                activeError = .downloadFailed(message)
            @unknown default:
                activeError = .downloadFailed(StringConstants.Dictation.analyzerUnavailableMessage.localized)
            }
        } catch {
            logger.error("Locale download failed: \(error.localizedDescription)")
            activeError = .downloadFailed(error.localizedDescription)
        }
        return success
    }

    // MARK: - Module resolution

    private func resolveModuleForDownload(locale: Locale) async -> (module: DictationTranscriber, status: AssetInventory.Status, preset: DictationTranscriber.Preset)? {
        for preset in Self.preferredPresets {
            let module = DictationTranscriber(locale: locale, preset: preset)
            let status = await AssetInventory.status(forModules: [module])
            switch status {
            case .unsupported:
                continue
            case .installed, .supported, .downloading:
                return (module, status, preset)
            @unknown default:
                continue
            }
        }
        return nil
    }

    private func resolveModuleForAnalysis(locale: Locale) async -> (module: DictationTranscriber, format: AVAudioFormat, preset: DictationTranscriber.Preset)? {
        for preset in Self.preferredPresets {
            let module = DictationTranscriber(locale: locale, preset: preset)
            let status = await AssetInventory.status(forModules: [module])
            guard status == .installed else { continue }
            if let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: nil) {
                return (module, format, preset)
            } else {
                // try next preset
            }
        }
        return nil
    }

    private func releaseStaleReservations(targetLocale: Locale) async {
        let reserved = await AssetInventory.reservedLocales
        let maxReservations = AssetInventory.maximumReservedLocales
        for locale in reserved {
            if locale.identifier == targetLocale.identifier {
                logger.debug("Releasing stale reservation for \(locale.identifier, privacy: .public)")
                await AssetInventory.release(reservedLocale: locale)
            }
        }
        if reserved.count >= maxReservations {
            for locale in reserved where locale.identifier != targetLocale.identifier {
                logger.debug("Releasing reservation for \(locale.identifier, privacy: .public) to honor maximum reservations")
                await AssetInventory.release(reservedLocale: locale)
            }
        }
    }

    private func releaseAllReservations(except targetLocale: Locale) async {
        let reserved = await AssetInventory.reservedLocales
        for locale in reserved where locale.identifier != targetLocale.identifier {
            logger.debug("Force-releasing reservation for \(locale.identifier, privacy: .public)")
            await AssetInventory.release(reservedLocale: locale)
        }
    }

    // MARK: - Dictation lifecycle

    func toggleDictation(with locale: Locale, noteStore: NoteStore) {
        attach(noteStore: noteStore)
        if isDictationRunning {
            Task { await stopDictation() }
        } else {
            Task { await startDictation(locale: locale) }
        }
    }

    func startDictation(locale: Locale) async {
        guard state == .idle else { return }
        guard #available(iOS 26, *) else {
            activeError = .analyzerUnavailable
            state = .failed
            return
        }
        guard let noteStore else {
            logger.error("No note store attached for dictation")
            activeError = .analyzerUnavailable
            return
        }

        let installed = await ensureLocaleInstalled(locale)
        let stillMissing = localeManager.localeRequiresDownload(locale)
        if !installed || stillMissing {
            state = .failed
            activeError = .localeAssetsMissing
            highlightedRange = nil
            interimTranscription = ""
            localeInUse = nil
            state = .idle
            return
        }

        state = .preparing
        localeInUse = locale
        baseContent = noteStore.currentNote.content
        startLocationUTF16 = baseContent.utf16.count
        committedTranscription = ""
        interimTranscription = ""
        highlightedRange = nil

        do {
            try await prepareAudioSession()
            try await preparePipeline(locale: locale)
            try await startCaptureTasks(noteStore: noteStore)
            state = .recording
        } catch DictationError.microphonePermissionDenied {
            state = .failed
            activeError = .microphonePermissionDenied
            await teardownPipeline()
            highlightedRange = nil
            interimTranscription = ""
            localeInUse = nil
            state = .idle
        } catch DictationError.localeAssetsMissing {
            state = .failed
            activeError = .localeAssetsMissing
            logger.error("Locale assets missing when starting dictation for \(locale.identifier, privacy: .public)")
            await teardownPipeline()
            highlightedRange = nil
            interimTranscription = ""
            localeInUse = nil
            state = .idle
        } catch {
            state = .failed
            logger.error("Failed to start dictation: \(error.localizedDescription)")
            activeError = .transcriptionFailed(error.localizedDescription)
            await teardownPipeline()
            highlightedRange = nil
            interimTranscription = ""
            localeInUse = nil
            state = .idle
        }
    }

    func stopDictation() async {
        guard isDictationRunning else { return }
        logger.debug("Stopping dictation pipeline")
        state = .finishing
        await teardownPipeline()
        state = .idle
        highlightedRange = nil
        interimTranscription = ""
        localeInUse = nil
    }

    // MARK: - Internal setup

    private func prepareAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        let granted: Bool
        if #available(iOS 17, *) {
            granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else { throw DictationError.microphonePermissionDenied }

        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothHFP, .defaultToSpeaker])
        try session.setActive(true, options: [])
    }

    private func preparePipeline(locale: Locale) async throws {
        guard let (transcriber, format, preset) = await resolveModuleForAnalysis(locale: locale) else {
            throw DictationError.localeAssetsMissing
        }

        await releaseStaleReservations(targetLocale: locale)
        if !(try await AssetInventory.reserve(locale: locale)) {
            await releaseAllReservations(except: locale)
            guard try await AssetInventory.reserve(locale: locale) else {
                let currentReservations = await AssetInventory.reservedLocales
                logger.error("Failed to reserve assets for locale \(locale.identifier, privacy: .public). Currently reserved: \(currentReservations.map { $0.identifier }.joined(separator: ", "), privacy: .public)")
                throw DictationError.analyzerUnavailable
            }
        }
        reservedLocale = locale
        self.transcriber = transcriber
        captureFormat = format

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        try await analyzer.prepareToAnalyze(in: format)

        let stream = AsyncStream<AnalyzerInput> { continuation in
            self.analyzerInputContinuation = continuation
        }
        try await analyzer.start(inputSequence: stream)
    }

    private func startCaptureTasks(noteStore: NoteStore) async throws {
        guard analyzer != nil, let transcriber, let captureFormat else {
            throw DictationError.analyzerUnavailable
        }
        let capturer = MicAudioCapturer()
        let micStream = try capturer.start()
        micCapturer = capturer

        guard let continuation = analyzerInputContinuation else {
            throw DictationError.analyzerUnavailable
        }

        let captureFormatCopy = captureFormat
        let continuationCopy = continuation

        analyzerInputTask = Task.detached(priority: .userInitiated) {
            var converter: AVAudioConverter?
            for await (buffer, _) in micStream {
                if Task.isCancelled { break }
                autoreleasepool {
                    if let converted = NoteDictationController.convert(buffer: buffer, to: captureFormatCopy, converter: &converter) {
                        let input = AnalyzerInput(buffer: converted)
                        continuationCopy.yield(input)
                    }
                }
            }
            continuationCopy.finish()
        }

        resultsTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    await self.handleTranscriptionResult(result, noteStore: noteStore)
                }
            } catch {
                NoteDictationController.audioLogger.error("Results task error: \(error.localizedDescription, privacy: .public)")
                await self.handleTranscriptionError(error)
            }
        }
    }

    // MARK: - Result handling

    @MainActor
    private func handleTranscriptionResult(_ result: DictationTranscriber.Result, noteStore: NoteStore) {
        let newText = String(result.text.characters)
        logger.debug("Received transcription result. isFinal=\(result.isFinal, privacy: .public) text=\(newText, privacy: .public)")
        if result.isFinal {
            committedTranscription = newText
            interimTranscription = ""
            updateNoteContent(noteStore: noteStore)
            baseContent += committedTranscription
            startLocationUTF16 = baseContent.utf16.count
            committedTranscription = ""
        } else {
            if newText.hasPrefix(committedTranscription) {
                let suffixIndex = newText.index(newText.startIndex, offsetBy: committedTranscription.count)
                interimTranscription = String(newText[suffixIndex...])
            } else {
                committedTranscription = ""
                interimTranscription = newText
            }
            updateNoteContent(noteStore: noteStore)
        }
    }

    @MainActor
    private func handleTranscriptionError(_ error: Error) {
        logger.error("Transcription error: \(error.localizedDescription)")
        activeError = .transcriptionFailed(error.localizedDescription)
    }

    private func updateNoteContent(noteStore: NoteStore) {
        let updated = baseContent + committedTranscription + interimTranscription
        noteStore.updateCurrentNoteContent(updated)
        if interimTranscription.isEmpty {
            highlightedRange = nil
        } else {
            let location = startLocationUTF16 + committedTranscription.utf16.count
            highlightedRange = NSRange(location: location, length: interimTranscription.utf16.count)
        }
    }

    // MARK: - Teardown

    private func teardownPipeline() async {
        micCapturer?.stop()
        micCapturer = nil
        analyzerInputContinuation?.finish()
        analyzerInputContinuation = nil

        analyzerInputTask?.cancel()
        analyzerInputTask = nil

        transcriber = nil
        analyzer = nil
        captureFormat = nil

        if let resultsTask {
            _ = await resultsTask.result
        }
        resultsTask = nil

        if let reservedLocale {
            await AssetInventory.release(reservedLocale: reservedLocale)
            self.reservedLocale = nil
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated private static func convert(buffer: AVAudioPCMBuffer, to format: AVAudioFormat, converter: inout AVAudioConverter?) -> AVAudioPCMBuffer? {
        if buffer.format == format {
            return buffer
        }
        if converter == nil || converter?.inputFormat != buffer.format || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(max(1, Double(buffer.frameCapacity) * ratio))
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        if let error {
            audioLogger.error("Audio conversion error: \(error.localizedDescription)")
            return nil
        }
        convertedBuffer.frameLength = AVAudioFrameCount(min(Double(convertedBuffer.frameCapacity), Double(buffer.frameLength) * ratio))
        return convertedBuffer
    }

}

// MARK: - MicAudioCapturer

final class MicAudioCapturer {
    private let audioEngine = AVAudioEngine()
    private var continuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation?

    func start() throws -> AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let stream = AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> { continuation in
            self.continuation = continuation
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                continuation.yield((buffer, time))
            }
        }
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.continuation?.finish()
            self.continuation = nil
            throw error
        }
        return stream
    }

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        continuation?.finish()
        continuation = nil
    }
}
