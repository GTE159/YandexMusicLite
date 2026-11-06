import SwiftUI

/// Bottom Player Bar anchored via safeAreaInset.
/// Modern macOS dark glass design with signature Yandex yellow accents,
/// custom sleek scrubbers, and isolated PlaybackProgressTracker redraw boundaries.
public struct PlayerBarView: View {
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var likesService = LikesService.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var coordinator = NavigationCoordinator.shared
    @UIState private var isFlameActive = false
    @UIState private var showVolumePopover = false
    @UIState private var isMuted = false
    @UIState private var previousVolume: Float = 1.0

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left: Track cover, Title, Artist, Like & Wave buttons
            leftTrackSection
                .frame(maxWidth: .infinity, alignment: .leading)

            // Center: Playback Controls & Isolated Progress Slider (strictly centered)
            centerControlsSection
                .frame(minWidth: windowState.isMiniWidth ? 180 : 260, maxWidth: 440)

            // Right: Lyrics, Quality Badge & Volume Control
            rightControlsSection
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, windowState.isCompactWidth ? 14 : 22)
        .padding(.vertical, 10)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                YMTheme.playerBg.opacity(0.85)
                VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
            }
        }
        .overlay(alignment: .top) {
            YMTheme.border
                .frame(height: 1)
        }
        .sheet(isPresented: $coordinator.isLyricsPresented) {
            LyricsSheetView(track: audioEngine.currentTrack)
        }
    }

    // MARK: - Left Track Section

    @ViewBuilder
    private var leftTrackSection: some View {
        HStack(spacing: 12) {
            let coverSize: CGFloat = windowState.isMiniWidth ? 38 : 46
            if let track = audioEngine.currentTrack {
                Button {
                    if let album = track.albums.first {
                        coordinator.navigate(to: .album(id: album.id, title: album.title))
                    }
                } label: {
                    CachedCoverImage(
                        coverUri: track.effectiveCoverUri,
                        size: .small,
                        displaySize: coverSize,
                        cornerRadius: 6
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help("Перейти к альбому")

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.displayTitle)
                        .font(.system(size: windowState.isMiniWidth ? 12 : 13, weight: .semibold))
                        .foregroundStyle(YMTheme.fg)
                        .lineLimit(1)

                    if let firstArtist = track.artists.first {
                        Button {
                            coordinator.navigate(to: .artist(id: firstArtist.id, name: firstArtist.name))
                        } label: {
                            Text(track.artistsString)
                                .font(.system(size: 11))
                                .foregroundStyle(YMTheme.fg60)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .help("Перейти к исполнителю")
                    } else {
                        Text(track.artistsString)
                            .font(.system(size: 11))
                            .foregroundStyle(YMTheme.fg60)
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 70, maxWidth: windowState.isCompactWidth ? 140 : 240, alignment: .leading)
                .layoutPriority(1)

                // Heart / Like button
                Button {
                    Task {
                        await likesService.toggleLike(track: track)
                    }
                } label: {
                    Image(systemName: likesService.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundColor(likesService.isLiked(trackId: track.id) ? YMTheme.heartRed : YMTheme.fg60)
                        .padding(7)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(likesService.isLiked(trackId: track.id) ? "Удалить из Мне нравится" : "Мне нравится")

                if !windowState.isMiniWidth {
                    Button {
                        audioEngine.startWave(forTrack: track)
                    } label: {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(YMTheme.fg60)
                            .padding(7)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Запустить Мою волну по этому треку")
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: coverSize, height: coverSize)

                Text("Ничего не играет")
                    .font(.system(size: 13))
                    .foregroundStyle(YMTheme.fg40)
                    .frame(minWidth: 70, maxWidth: 200, alignment: .leading)
            }
        }
    }

    // MARK: - Center Controls Section

    @ViewBuilder
    private var centerControlsSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: windowState.isCompactWidth ? 12 : 18) {
                // Wave tuning or Shuffle
                HStack(spacing: 8) {
                    if audioEngine.isWaveMode {
                        Button {
                            audioEngine.applyWaveTuning(.moreLikeThis)
                            isFlameActive = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                await MainActor.run {
                                    isFlameActive = false
                                }
                            }
                        } label: {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(isFlameActive ? Color.orange : YMTheme.accent)
                                .padding(7)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(audioEngine.currentTrack == nil)
                        .help("Больше таких треков")

                        Button {
                            audioEngine.applyWaveTuning(.lessLikeThis)
                        } label: {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(YMTheme.fg60)
                                .padding(7)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(audioEngine.currentTrack == nil)
                        .help("Меньше таких треков")
                    } else {
                        Button {
                            audioEngine.toggleShuffle()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13))
                                .foregroundStyle(audioEngine.isShuffleEnabled ? YMTheme.accent : YMTheme.fg60)
                                .padding(7)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(audioEngine.currentTrack == nil && audioEngine.queue.isEmpty)
                        .help(audioEngine.isShuffleEnabled ? "Выключить перемешивание" : "Перемешать очередь")
                    }
                }
                .frame(width: 58, alignment: .trailing)

                // Previous Track
                Button {
                    audioEngine.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(audioEngine.currentTrack == nil ? YMTheme.fg40 : YMTheme.fg)
                }
                .buttonStyle(.plain)
                .disabled(audioEngine.currentTrack == nil)
                .help("Предыдущий трек")

                // Play / Pause prominent Button (Signature Yellow Disc)
                Button {
                    audioEngine.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(YMTheme.accent)
                            .frame(width: 36, height: 36)
                            .shadow(color: YMTheme.accent.opacity(audioEngine.isPlaying ? 0.35 : 0.15), radius: 6, y: 1)

                        Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.black)
                            .offset(x: audioEngine.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(audioEngine.currentTrack == nil)
                .help(audioEngine.isPlaying ? "Пауза (Пробел)" : "Воспроизведение (Пробел)")

                // Next Track
                Button {
                    audioEngine.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(audioEngine.currentTrack == nil ? YMTheme.fg40 : YMTheme.fg)
                }
                .buttonStyle(.plain)
                .disabled(audioEngine.currentTrack == nil)
                .help("Следующий трек")

                // Symmetric right spacer
                Color.clear
                    .frame(width: 58, height: 1)
            }

            // Isolated Scrubber View
            IsolatedProgressSlider(
                progressTracker: audioEngine.progressTracker,
                onSeekCommit: { seconds in
                    audioEngine.seek(to: seconds)
                }
            )
        }
    }

    // MARK: - Right Controls Section

    @ViewBuilder
    private var rightControlsSection: some View {
        HStack(spacing: windowState.isCompactWidth ? 10 : 14) {
            // Lyrics Button
            Button {
                coordinator.isLyricsPresented = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 14))
                    .foregroundStyle(coordinator.isLyricsPresented ? YMTheme.accent : YMTheme.fg60)
            }
            .buttonStyle(.plain)
            .disabled(audioEngine.currentTrack == nil)
            .help("Показать текст песни")

            // Quality Badge Menu
            if !windowState.isMiniWidth {
                AudioQualityMenu(audioEngine: audioEngine)
            }

            // Volume Control
            HStack(spacing: 8) {
                Button {
                    toggleMute()
                } label: {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(YMTheme.fg60)
                        .frame(width: 18)
                }
                .buttonStyle(.plain)
                .help(isMuted ? "Включить звук" : "Выключить звук")

                YMSlider(
                    value: Binding(
                        get: { Double(audioEngine.volume) },
                        set: {
                            audioEngine.volume = Float($0)
                            if $0 > 0 { isMuted = false }
                        }
                    ),
                    in: 0...1,
                    activeColor: YMTheme.fg,
                    trackColor: Color.white.opacity(0.12),
                    height: 3
                )
                .frame(width: windowState.isCompactWidth ? 64 : 86)
            }
        }
    }

    private var volumeIcon: String {
        if isMuted || audioEngine.volume == 0 {
            return "speaker.slash.fill"
        } else if audioEngine.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if audioEngine.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func toggleMute() {
        if isMuted {
            audioEngine.volume = previousVolume > 0 ? previousVolume : 0.5
            isMuted = false
        } else {
            previousVolume = audioEngine.volume
            audioEngine.volume = 0
            isMuted = true
        }
    }
}

// MARK: - Audio Quality Dropdown Menu

private struct AudioQualityMenu: View {
    @Bindable var audioEngine: AudioPlayerEngine
    @Bindable var qualitySettings = AudioQualitySettings.shared

    var body: some View {
        Menu {
            Section("Качество звука") {
                ForEach(YMAudioQualityPreset.allCases) { preset in
                    Button {
                        audioEngine.setAudioQualityPreset(preset)
                    } label: {
                        HStack {
                            Text(preset.title)
                            if qualitySettings.preset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Предпочитаемый кодек") {
                ForEach(YMAudioCodecPreference.allCases) { codec in
                    Button {
                        audioEngine.setCodecPreference(codec)
                    } label: {
                        HStack {
                            Text(codec.title)
                            if qualitySettings.codecPreference == codec {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if let formatDetails = audioEngine.currentAudioFormatDetails {
                Section("Аппаратный поток (AVPlayer)") {
                    Text(formatDetails)
                }
            }

            if !audioEngine.availableStreamInfos.isEmpty {
                Section("Доступные потоки трека") {
                    ForEach(audioEngine.availableStreamInfos) { info in
                        Button {
                            audioEngine.selectStreamVariant(info)
                        } label: {
                            HStack {
                                Text(info.displayDescription)
                                if audioEngine.currentStreamInfo?.matchesVariant(info) == true {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.system(size: 9))
                Text(badgeTitle)
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeBackground)
            .foregroundColor(badgeForeground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isLosslessActive ? YMTheme.accent.opacity(0.3) : YMTheme.border, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Настройки качества звука")
    }

    private var badgeTitle: String {
        if let info = audioEngine.currentStreamInfo {
            if info.isLossless {
                return "LOSSLESS"
            }
            return "\(info.bitrateInKbps)K \(info.displayCodec)"
        }
        return audioEngine.qualitySettings.preset.shortBadge
    }

    private var isLosslessActive: Bool {
        audioEngine.currentStreamInfo?.isLossless == true || audioEngine.qualitySettings.preset == .lossless
    }

    private var badgeBackground: Color {
        if isLosslessActive {
            return YMTheme.accent.opacity(0.18)
        }
        return Color.white.opacity(0.08)
    }

    private var badgeForeground: Color {
        if isLosslessActive {
            return YMTheme.accent
        }
        return YMTheme.fg80
    }
}

// MARK: - Isolated Progress Slider

/// Isolated Slider component bound only to `PlaybackProgressTracker`.
/// High-frequency ticks (up to 4-10 times/sec) do not re-render the parent PlayerBar or Navigation split view.
private struct IsolatedProgressSlider: View {
    @Bindable var progressTracker: PlaybackProgressTracker
    let onSeekCommit: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(progressTracker.currentTimeFormatted)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(YMTheme.fg60)
                .frame(width: 38, alignment: .trailing)

            YMSlider(
                value: Binding(
                    get: { progressTracker.progress },
                    set: { progressTracker.progress = $0 }
                ),
                in: 0...1,
                activeColor: YMTheme.accent,
                trackColor: Color.white.opacity(0.14),
                height: 3,
                onEditingChanged: { editing in
                    progressTracker.isUserSeeking = editing
                    if !editing {
                        onSeekCommit(progressTracker.currentTime)
                    }
                }
            )

            Text(progressTracker.durationFormatted)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(YMTheme.fg40)
                .frame(width: 38, alignment: .leading)
        }
    }
}
