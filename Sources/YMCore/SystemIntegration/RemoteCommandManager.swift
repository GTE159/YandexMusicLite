import Foundation
import MediaPlayer

/// Manages macOS System Remote Command Center integration (Media Keys, Touch Bar, Control Center).
@MainActor
public final class RemoteCommandManager {
    public static let shared = RemoteCommandManager()

    private weak var playerEngine: AudioPlayerEngine?
    public var onLikeToggled: (@Sendable () -> Void)?

    public init(playerEngine: AudioPlayerEngine = AudioPlayerEngine.shared) {
        self.playerEngine = playerEngine
        setupCommands()
    }

    deinit {
        // Detach all targets
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
    }

    public func configure(with engine: AudioPlayerEngine) {
        self.playerEngine = engine
    }

    private func setupCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play / Pause / Toggle
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerEngine?.play()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerEngine?.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerEngine?.togglePlayPause()
            }
            return .success
        }

        // Track navigation
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerEngine?.next()
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerEngine?.previous()
            }
            return .success
        }

        // Seek scrubber
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let positionTime = positionEvent.positionTime
            Task { @MainActor [weak self] in
                self?.playerEngine?.seek(to: positionTime)
                NowPlayingController.shared.updatePlaybackPosition(seconds: positionTime, isPlaying: self?.playerEngine?.isPlaying ?? false)
            }
            return .success
        }

        // Like command
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.localizedTitle = "Мне нравится"
        commandCenter.likeCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onLikeToggled?()
            }
            return .success
        }
    }
}
