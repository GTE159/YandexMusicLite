import Foundation
import MediaPlayer
import AppKit

/// Controls macOS System Now Playing metadata in Control Center and lock screen.
/// strictly updates MPNowPlayingInfoCenter only on state events (play, pause, track change, seek finish)
/// to eliminate IPC overhead and keep memory low.
@MainActor
public final class NowPlayingController {
    public static let shared = NowPlayingController()

    private var currentArtworkTask: Task<Void, Never>?
    private var currentTrackId: String?

    public init() {}

    /// Updates Now Playing metadata on track change or initial playback
    public func updateTrack(
        _ track: YMTrack,
        isPlaying: Bool,
        currentTime: Double = 0,
        duration: Double? = nil
    ) {
        self.currentTrackId = track.id
        var info: [String: Any] = [:]

        info[MPMediaItemPropertyTitle] = track.displayTitle
        info[MPMediaItemPropertyArtist] = track.artistsString

        if let album = track.albums.first {
            info[MPMediaItemPropertyAlbumTitle] = album.title
        }

        let trackDuration = duration ?? (Double(track.durationMs ?? 0) / 1000.0)
        if trackDuration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = trackDuration
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Fetch artwork asynchronously and downsample to 300x300 via shared ImagePipeline
        currentArtworkTask?.cancel()
        if let coverUri = track.effectiveCoverUri, !coverUri.isEmpty {
            currentArtworkTask = Task { [weak self] in
                guard let image = await ImagePipeline.shared.image(for: coverUri, size: .artwork) else {
                    return
                }
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self = self, self.currentTrackId == track.id else { return }
                    self.setArtwork(image: image)
                }
            }
        }
    }

    /// Updates only the playback rate and elapsed time on play / pause toggle
    public func updatePlaybackState(isPlaying: Bool, currentTime: Double) {
        guard var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        currentInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        currentInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
    }

    /// Updates elapsed time upon seek completion
    public func updatePlaybackPosition(seconds: Double, isPlaying: Bool) {
        guard var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        currentInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        currentInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
    }

    public func updatePlaybackPosition(currentTime seconds: Double, isPlaying: Bool) {
        updatePlaybackPosition(seconds: seconds, isPlaying: isPlaying)
    }

    /// Sets downsampled artwork into the active nowPlayingInfo dictionary
    private func setArtwork(image: NSImage) {
        guard var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in
            return image
        }
        currentInfo[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
    }

    /// Clears Now Playing center when playback is stopped
    public func clearNowPlaying() {
        currentArtworkTask?.cancel()
        currentArtworkTask = nil
        currentTrackId = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
