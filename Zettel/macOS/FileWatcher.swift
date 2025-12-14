//
//  FileWatcher.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Foundation
import CoreServices

final class FileWatcher {
    private var stream: FSEventStreamRef?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var handler: (() -> Void)?

    func start(on folderURL: URL, handler: @escaping () -> Void) {
        stop()
        self.handler = handler
        if startFSEvents(on: folderURL) == false {
            startDispatchSource(on: folderURL)
        }
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil

        if let dispatchSource {
            dispatchSource.cancel()
        }
        dispatchSource = nil

        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        handler = nil
    }

    deinit {
        stop()
    }

    private func startFSEvents(on url: URL) -> Bool {
        let callback: FSEventStreamCallback = { (_, info, _, _, _, _) in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.publish()
        }

        var context = FSEventStreamContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [url.path as NSString] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagNoDefer
            )
        ) else {
            return false
        }

        self.stream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        return true
    }

    private func startDispatchSource(on url: URL) {
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        let queue = DispatchQueue(label: "zettel-desktop.filewatcher")
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.write, .extend, .attrib, .delete, .rename], queue: queue)
        source.setEventHandler { [weak self] in
            self?.publish()
        }
        source.setCancelHandler { [fd = fileDescriptor] in
            if fd != -1 {
                close(fd)
            }
        }
        source.resume()
        dispatchSource = source
    }

    private func publish() {
        guard let handler else { return }
        DispatchQueue.main.async {
            handler()
        }
    }
}

