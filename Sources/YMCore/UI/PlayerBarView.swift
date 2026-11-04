import SwiftUI

/// Bottom Player Bar anchored via safeAreaInset.
/// Uses isolated `@Observable PlaybackProgressTracker` to eliminate redundant redraws of other components.
public struct PlayerBarView: View {
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var likesService = LikesService.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var isFlameActive = false
    @UIState private var showVolumePopover = false

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left: Track cover, Title, Artist, Like button
            HStack(spacing: windowState.isMiniWidth ? 8 : 12) {
                let coverSize: CGFloat = windowState.isMiniWidth ? 36 : 44
                if let track = audioEngine.currentTrack {
                    CachedCoverImage(
                        coverUri: track.effectiveCoverUri,
                        size: .small,
                        displaySize: coverSize,
                        cornerRadius: 6
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle)
                            .font(.system(size: windowState.isMiniWidth ? 12 : 13, weight: .medium))
                            .lineLimit(1)

                        Text(track.artistsString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 60, maxWidth: windowState.isCompactWidth ? 120 : 180, alignment: .leading)
                    .layoutPriority(1)

                    Button {
                        Task {
                            await likesService.toggleLike(track: track)
                        }
                    } label: {
                        Image(systemName: likesService.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                            .foregroundColor(likesService.isLiked(trackId: track.id) ? .red : .secondary)
                            .font(.system(size: windowState.isMiniWidth ? 13 : 15))
                    }
                    .buttonStyle(.plain)

                    if !windowState.isMiniWidth {
                        Button {
                            audioEngine.startWave(forTrack: track)
                        } label: {
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Запустить волну по этому треку")
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: coverSize, height: coverSize)

                    Text("Ничего не играет")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 60, maxWidth: windowState.isCompactWidth ? 120 : 180, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center: Playback Controls & Isolated Progress Slider (strictly centered)
            VStack(spacing: 6) {
                HStack(spacing: windowState.isCompactWidth ? 10 : 16) {
                    // Left anchor to balance Previous / Play / Next in the exact middle
                    HStack(spacing: windowState.isCompactWidth ? 8 : 12) {
                        if audioEngine.isWaveMode {
                            Button {
                                audioEngine.applyWaveTuning(.lessLikeThis)
                            } label: {
                                Image(systemName: "hand.thumbsdown")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(audioEngine.currentTrack == nil)
                            .help("Меньше таких треков — пропустить и скорректировать волну")

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
                                Image(systemName: isFlameActive ? "flame.fill" : "flame")
                                    .font(.system(size: 14))
                                    .foregroundColor(isFlameActive ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(audioEngine.currentTrack == nil)
                            .help("Больше похожих треков — усилить этот стиль в волне без добавления в Избранное")
                        } else {
                            Button {
                                audioEngine.toggleShuffle()
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 14))
                                    .foregroundColor(audioEngine.isShuffleEnabled ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(audioEngine.currentTrack == nil && audioEngine.queue.isEmpty)
                            .help(audioEngine.isShuffleEnabled ? "Выключить перемешивание" : "Перемешать очередь")
                        }
                    }
                    .frame(width: windowState.isCompactWidth ? nil : 44, alignment: .trailing)

                    Button {
                        audioEngine.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(audioEngine.currentTrack == nil)

                    Button {
                        audioEngine.togglePlayPause()
                    } label: {
                        Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.plain)
                    .disabled(audioEngine.currentTrack == nil)

                    Button {
                        audioEngine.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(audioEngine.currentTrack == nil)

                    // Right symmetrical balance spacer
                    if !windowState.isCompactWidth {
                        Color.clear
                            .frame(width: 44, height: 1)
                    }
                }

                // Isolated Scrubber View
                IsolatedProgressSlider(
                    progressTracker: audioEngine.progressTracker,
                    onSeekCommit: { seconds in
                        audioEngine.seek(to: seconds)
                    }
                )
            }
            .frame(minWidth: windowState.isMiniWidth ? 160 : 220, maxWidth: 400)

            // Right: Quality Picker & Volume Slider
            HStack(spacing: windowState.isCompactWidth ? 8 : 12) {
                if !windowState.isMiniWidth {
                    AudioQualityMenu(audioEngine: audioEngine)
                }

                if windowState.isMiniWidth {
                    Button {
                        showVolumePopover.toggle()
                    } label: {
                        Image(systemName: audioEngine.volume > 0.5 ? "speaker.wave.3.fill" : (audioEngine.volume > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showVolumePopover, arrowEdge: .top) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { audioEngine.volume },
                                    set: { audioEngine.volume = $0 }
                                ),
                                in: 0...1
                            )
                            .frame(width: 120)
                            .controlSize(.small)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }
                    .help("Громкость: \(Int(audioEngine.volume * 100))%")
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: audioEngine.volume > 0.5 ? "speaker.wave.3.fill" : (audioEngine.volume > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Slider(
                            value: Binding(
                                get: { audioEngine.volume },
                                set: { audioEngine.volume = $0 }
                            ),
                            in: 0...1
                        )
                        .frame(width: windowState.isCompactWidth ? 56 : 80)
                        .controlSize(.small)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, windowState.isCompactWidth ? 12 : 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
                    Color(NSColor.controlBackgroundColor).opacity(0.25)
                }
            }
            .overlay(alignment: .top) {
                Color.primary.opacity(0.1)
                    .frame(height: 0.5)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -3)
        }
    }

/// Interactive quality and codec selection menu for the Player Bar.
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
                    .font(.system(size: 10, weight: .semibold))
                    .frame(minWidth: 54, alignment: .center)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(badgeBackground)
            .foregroundColor(badgeForeground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
            return Color.orange.opacity(0.18)
        }
        return Color.secondary.opacity(0.12)
    }

    private var badgeForeground: Color {
        if isLosslessActive {
            return Color.orange
        }
        return Color.secondary
    }
}

/// Isolated Slider component bound only to `PlaybackProgressTracker`.
/// High-frequency ticks (up to 4-10 times/sec) do not re-render the parent PlayerBar or Navigation split view.
private struct IsolatedProgressSlider: View {
    @Bindable var progressTracker: PlaybackProgressTracker
    let onSeekCommit: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(progressTracker.currentTimeFormatted)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { progressTracker.progress },
                    set: { progressTracker.progress = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    progressTracker.isUserSeeking = editing
                    if !editing {
                        onSeekCommit(progressTracker.currentTime)
                    }
                }
            )
            .controlSize(.small)

            Text(progressTracker.durationFormatted)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }
}
