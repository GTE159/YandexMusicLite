import SwiftUI

/// Modern, visually stunning "Моя волна" view featuring an animated pulsing wave orb,
/// interactive vibe presets, tuning controls, and the upcoming wave queue.
public struct MyWaveView: View {
    @UIState private var waveTracks: [YMTrack] = []
    @UIState private var rotorService = RotorService.shared
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var coordinator = NavigationCoordinator.shared
    @UIState private var likesService = LikesService.shared

    @UIState private var isLoadingWave = false
    @UIState private var isLoadingMoreWave = false
    @UIState private var errorMessage: String? = nil
    @UIState private var toastMessage: String? = nil
    @UIState private var toastDismissTask: Task<Void, Never>? = nil
    @UIState private var waveOrbRotation: Double = 0
    @UIState private var waveOrbScale: CGFloat = 1.0

    public init() {}

    private var displayedWaveTracks: [YMTrack] {
        if audioEngine.isWaveMode && !audioEngine.queue.isEmpty {
            return audioEngine.queue
        }
        return waveTracks
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 24) {
                // Wave Hero Card with Animated Orb
                waveHeroCard

                // Vibe Presets Selector
                vibePresetsSelector

                // Tuning Feedback Toast
                if let toast = toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(YMTheme.accent)
                            .font(.system(size: 13))
                        Text(toast)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(YMTheme.fg)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(YMTheme.border, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Error message banner
                if let error = errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Ошибка загрузки волны: \(error)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Повторить") {
                            startWave(context: audioEngine.activeWaveContext, vibe: audioEngine.activeWaveVibe)
                        }
                        .buttonStyle(YMGlassPillButtonStyle(primary: true, height: 28))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                }

                // Upcoming Wave Queue Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Далее в волне")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(YMTheme.fg)

                            Text("Треки, подобранные алгоритмом на основе ваших предпочтений")
                                .font(.caption)
                                .foregroundStyle(YMTheme.fg40)
                        }

                        Spacer()

                        if isLoadingMoreWave {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 24)

                    if displayedWaveTracks.isEmpty && isLoadingWave {
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Подбираем музыку для вашей волны...")
                                .font(.caption)
                                .foregroundStyle(YMTheme.fg40)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if displayedWaveTracks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 40))
                                .foregroundStyle(YMTheme.fg40)
                            Text("Волна готова к воспроизведению")
                                .font(.headline)
                                .foregroundStyle(YMTheme.fg)
                            Button {
                                startWave(context: .myWaveDefault, vibe: .defaultWave)
                            } label: {
                                Label("Включить Мою волну", systemImage: "play.fill")
                            }
                            .buttonStyle(YMGlassPillButtonStyle(primary: true, height: 36))
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        TrackTableView(
                            tracks: displayedWaveTracks,
                            onPlayTrack: { track in
                                if let idx = displayedWaveTracks.firstIndex(where: { $0.id == track.id }) {
                                    audioEngine.playTrack(at: idx)
                                }
                            },
                            onLoadMore: {
                                Task {
                                    await loadMoreTracks()
                                }
                            }
                        )
                        .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .ymScreenBackground()
        .onAppear {
            if audioEngine.isWaveMode && !audioEngine.queue.isEmpty {
                waveTracks = audioEngine.queue
            } else if waveTracks.isEmpty && !audioEngine.isWaveMode {
                startWave(context: .myWaveDefault, vibe: .defaultWave)
            }
            setupWaveChangeHooks()
        }
    }

    // MARK: - Wave Hero Card with Animated Orb

    private var waveHeroCard: some View {
        ZStack {
            // Ambient background glow
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 30 / 255, green: 25 / 255, blue: 10 / 255),
                            Color(red: 20 / 255, green: 15 / 255, blue: 25 / 255),
                            Color(red: 14 / 255, green: 14 / 255, blue: 18 / 255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(YMTheme.border, lineWidth: 1)
                )

            HStack(spacing: 28) {
                // Pulsing Animated Orb
                ZStack {
                    // Outer pulsating halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    YMTheme.accent.opacity(audioEngine.isPlaying ? 0.35 : 0.15),
                                    Color.purple.opacity(audioEngine.isPlaying ? 0.25 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 85
                            )
                        )
                        .frame(width: 170, height: 170)
                        .scaleEffect(audioEngine.isPlaying ? waveOrbScale : 1.0)
                        .animation(audioEngine.isPlaying ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default, value: waveOrbScale)

                    // Rotating inner gradient orb
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255),
                                    Color(red: 255 / 255, green: 102 / 255, blue: 0 / 255),
                                    Color(red: 233 / 255, green: 30 / 255, blue: 99 / 255),
                                    Color(red: 156 / 255, green: 39 / 255, blue: 176 / 255),
                                    Color(red: 33 / 255, green: 150 / 255, blue: 243 / 255),
                                    Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255)
                                ],
                                center: .center
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 12)
                        .rotationEffect(.degrees(waveOrbRotation))
                        .animation(audioEngine.isPlaying ? .linear(duration: 12).repeatForever(autoreverses: false) : .default, value: waveOrbRotation)

                    // Central Play / Pause Button
                    Button {
                        if audioEngine.isWaveMode && audioEngine.isPlaying {
                            audioEngine.pause()
                        } else if audioEngine.isWaveMode {
                            audioEngine.play()
                        } else {
                            startWave(context: audioEngine.activeWaveContext, vibe: audioEngine.activeWaveVibe)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.75))
                                .frame(width: 56, height: 56)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5))

                            Image(systemName: (audioEngine.isWaveMode && audioEngine.isPlaying) ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(YMTheme.accent)
                                .offset(x: (audioEngine.isWaveMode && audioEngine.isPlaying) ? 0 : 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                }
                .frame(width: 170, height: 170)
                .onAppear {
                    waveOrbRotation = 360
                    waveOrbScale = 1.15
                }

                // Info & Now Playing
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(YMTheme.accent)

                        Text(audioEngine.activeWaveContext.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(YMTheme.fg)

                        if audioEngine.activeWaveContext != .myWaveDefault {
                            Button {
                                startWave(context: .myWaveDefault, vibe: .defaultWave)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(YMTheme.fg60)
                            }
                            .buttonStyle(.plain)
                            .help("Сбросить к Моей волне")
                        }
                    }

                    Text(audioEngine.activeWaveContext.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(YMTheme.fg60)
                        .lineLimit(2)

                    // Current track info if active
                    if let track = audioEngine.currentTrack, audioEngine.isWaveMode {
                        HStack(spacing: 12) {
                            CachedCoverImage(
                                coverUri: track.effectiveCoverUri,
                                size: .small,
                                displaySize: 42,
                                cornerRadius: 6
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.displayTitle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(YMTheme.fg)
                                    .lineLimit(1)

                                Text(track.artistsString)
                                    .font(.caption)
                                    .foregroundStyle(YMTheme.fg60)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Wave Tuning Fast Buttons
                            HStack(spacing: 8) {
                                Button {
                                    audioEngine.applyWaveTuning(.moreLikeThis)
                                    showToast("Алгоритм учёл: больше треков в стиле «\(track.displayTitle)»")
                                } label: {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(YMTheme.accent)
                                        .padding(8)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .help("Больше таких треков")

                                Button {
                                    audioEngine.applyWaveTuning(.lessLikeThis)
                                    showToast("Пропущено: меньше треков в стиле «\(track.displayTitle)»")
                                } label: {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(YMTheme.fg60)
                                        .padding(8)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .help("Меньше таких треков")

                                Button {
                                    Task {
                                        await likesService.toggleLike(track: track)
                                    }
                                } label: {
                                    Image(systemName: likesService.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 13))
                                        .foregroundColor(likesService.isLiked(trackId: track.id) ? YMTheme.heartRed : YMTheme.fg60)
                                        .padding(8)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .help("Мне нравится")
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.3))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(YMTheme.border, lineWidth: 1))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Vibe Presets Selector

    private var vibePresetsSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Характер звучания")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(YMTheme.fg80)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(YMWaveVibePreset.allCases) { preset in
                        let isSelected = audioEngine.activeWaveVibe == preset
                        Button {
                            guard audioEngine.activeWaveVibe != preset || !audioEngine.isWaveMode else { return }
                            audioEngine.activeWaveVibe = preset
                            startWave(context: audioEngine.activeWaveContext, vibe: preset)
                            showToast("Характер волны: \(preset.title)")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 12))
                                Text(preset.title)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? YMTheme.accent : Color.white.opacity(0.08))
                            )
                            .foregroundColor(isSelected ? .black : YMTheme.fg)
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.clear : YMTheme.border, lineWidth: 1)
                            )
                            .scaleEffect(isSelected ? 1.02 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }

                    // Diversity Button
                    Button {
                        audioEngine.applyWaveTuning(.moreDiversity)
                        showToast("Перенастройка волны: добавлено больше разнообразия")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text("Больше открытий")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundColor(YMTheme.fg)
                        .overlay(Capsule().strokeBorder(YMTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Добавить больше неожиданных открытий")
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Wave Logic & Telemetry

    private func startWave(context: YMWaveContext, vibe: YMWaveVibePreset) {
        isLoadingWave = true
        errorMessage = nil

        Task {
            do {
                let initialTracks = try await rotorService.startWave(context: context, vibe: vibe)
                await MainActor.run {
                    self.waveTracks = initialTracks
                    self.isLoadingWave = false
                    self.audioEngine.activeWaveContext = context
                    self.audioEngine.activeWaveVibe = vibe
                    self.audioEngine.isWaveMode = true
                    self.audioEngine.setQueue(initialTracks, startingAt: 0)
                }
            } catch {
                await MainActor.run {
                    self.isLoadingWave = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadMoreTracks() async {
        guard !isLoadingMoreWave, let lastTrack = waveTracks.last else { return }
        isLoadingMoreWave = true

        let history = Array(waveTracks.suffix(5)).map(\.rotorTrackIdentifier)
        do {
            let nextBatch = try await rotorService.fetchNextBatch(
                lastTrackId: lastTrack.rotorTrackIdentifier,
                queueHistory: history
            )
            await MainActor.run {
                let existingIds = Set(self.waveTracks.map(\.id))
                let newUnique = nextBatch.filter { !existingIds.contains($0.id) }
                self.waveTracks.append(contentsOf: newUnique)
                self.audioEngine.appendToQueue(newUnique)
                self.isLoadingMoreWave = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingMoreWave = false
            }
        }
    }

    private func setupWaveChangeHooks() {
        audioEngine.onQueueNeedsMoreTracks = {
            Task {
                await loadMoreTracks()
            }
        }

        audioEngine.onStartCustomWaveRequested = { [self] context, vibe in
            Task { @MainActor in
                self.startWave(context: context, vibe: vibe ?? .defaultWave)
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation {
                    self.toastMessage = nil
                }
            }
        }
    }
}
