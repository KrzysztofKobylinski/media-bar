import AppKit
import Darwin

final class MediaController {
    static let shared = MediaController()
    static let playbackDidChange = Notification.Name("MediaController.playbackDidChange")

    private(set) var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else { return }
            NotificationCenter.default.post(name: Self.playbackDidChange, object: self)
        }
    }

    private var ignoreRemoteUntil = Date.distantPast
    private let mediaRemote = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        RTLD_LAZY
    )

    private init() {
        registerForNowPlaying()
        refresh()
    }

    func togglePlayPause() {
        isPlaying.toggle()
        ignoreRemoteUntil = Date().addingTimeInterval(1.5)
        // Discrete pause is ignored by Chrome/YouTube; toggle matches the media key.
        if !send(command: 2) {
            postPlayKey()
        }
    }

    func refresh() {
        guard let mediaRemote,
              let symbol = dlsym(mediaRemote, "MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        else { return }

        typealias GetIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
        unsafeBitCast(symbol, to: GetIsPlaying.self)(DispatchQueue.main) { [weak self] playing in
            guard let self, Date() >= self.ignoreRemoteUntil else { return }
            self.isPlaying = playing
        }
    }

    private func registerForNowPlaying() {
        guard let mediaRemote,
              let symbol = dlsym(mediaRemote, "MRMediaRemoteRegisterForNowPlayingNotifications")
        else { return }

        typealias Register = @convention(c) (DispatchQueue) -> Void
        unsafeBitCast(symbol, to: Register.self)(.main)

        for name in [
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ] {
            NotificationCenter.default.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        }
    }

    private func send(command: Int32) -> Bool {
        guard let mediaRemote,
              let symbol = dlsym(mediaRemote, "MRMediaRemoteSendCommand")
        else { return false }

        typealias SendCommand = @convention(c) (Int32, CFDictionary?) -> DarwinBoolean
        return unsafeBitCast(symbol, to: SendCommand.self)(command, nil).boolValue
    }

    private func postPlayKey() {
        func post(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((16 << 16) | ((down ? 0xA : 0xB) << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { return }
            event.cgEvent?.post(tap: .cgSessionEventTap)
        }
        post(down: true)
        post(down: false)
    }
}
