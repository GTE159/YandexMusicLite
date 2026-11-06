import SwiftUI

/// Chart (Чарт) view showing the Top 100 most popular tracks in Yandex Music with positions and shifts.
public struct ChartView: View {
    @UIState private var chartItems: [YMChartItem] = []
    @UIState private var isLoading = true
    @UIState private var errorMessage: String? = nil

    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var likesService = LikesService.shared
    @UIState private var coordinator = NavigationCoordinator.shared
    private let networkClient = YMNetworkClient.shared

    public init() {}

    private var chartTracks: [YMTrack] {
        chartItems.compactMap(\.track)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Чарт")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(YMTheme.fg)

                    Text("Топ треков, которые прямо сейчас слушают в Яндекс Музыке")
                        .font(.caption)
                        .foregroundStyle(YMTheme.fg60)
                }

                Spacer()

                if !chartTracks.isEmpty {
                    Button {
                        audioEngine.assignQueue(chartTracks, startingAt: 0)
                    } label: {
                        Label("Слушать чарт", systemImage: "play.fill")
                    }
                    .buttonStyle(YMGlassPillButtonStyle(primary: true, height: 34))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 24)

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Загрузка чарта...")
                        .font(.caption)
                        .foregroundStyle(YMTheme.fg40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Повторить") {
                        loadChart()
                    }
                    .buttonStyle(YMGlassPillButtonStyle(primary: true))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(chartItems.enumerated()), id: \.element.id) { index, item in
                            if let track = item.track {
                                ChartTrackRow(
                                    item: item,
                                    track: track,
                                    index: index,
                                    isPlaying: audioEngine.currentTrack?.id == track.id && audioEngine.isPlaying,
                                    onPlay: {
                                        audioEngine.assignQueue(chartTracks, startingAt: index)
                                    },
                                    onArtistSelect: { artist in
                                        coordinator.navigate(to: .artist(id: artist.id, name: artist.name))
                                    },
                                    onAlbumSelect: { album in
                                        coordinator.navigate(to: .album(id: album.id, title: album.title))
                                    }
                                )
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .ymScreenBackground()
        .task {
            if chartItems.isEmpty {
                loadChart()
            }
        }
    }

    private func loadChart() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let items = try await networkClient.fetchChart()
                await MainActor.run {
                    self.chartItems = items
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Не удалось загрузить чарт: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

private struct ChartTrackRow: View {
    let item: YMChartItem
    let track: YMTrack
    let index: Int
    let isPlaying: Bool
    let onPlay: () -> Void
    let onArtistSelect: (YMArtist) -> Void
    let onAlbumSelect: (YMAlbum) -> Void

    @UIState private var likesService = LikesService.shared
    @UIState private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Position rank
            HStack(spacing: 4) {
                let pos = item.chart?.position ?? (index + 1)
                Text("\(pos)")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(pos <= 3 ? YMTheme.accent : YMTheme.fg80)
                    .frame(width: 28, alignment: .trailing)

                shiftBadge
                    .frame(width: 16)
            }

            // Play indicator
            Button {
                onPlay()
            } label: {
                if isPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(YMTheme.accent)
                        .font(.system(size: 13))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(isHovered ? YMTheme.fg : YMTheme.fg60)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 20)

            // Cover
            CachedCoverImage(
                coverUri: track.effectiveCoverUri,
                size: .small,
                displaySize: 36,
                cornerRadius: 4
            )

            // Title & Artists
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: isPlaying ? .semibold : .regular))
                    .foregroundStyle(isPlaying ? YMTheme.accent : YMTheme.fg)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(track.artists) { artist in
                        Button {
                            onArtistSelect(artist)
                        } label: {
                            Text(artist.name)
                                .font(.caption)
                                .foregroundStyle(YMTheme.fg40)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 140, alignment: .leading)

            Spacer()

            // Album
            if let album = track.albums.first {
                Button {
                    onAlbumSelect(album)
                } label: {
                    Text(album.title)
                        .font(.caption)
                        .foregroundStyle(YMTheme.fg40)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 160, alignment: .leading)
            }

            // Like Button
            Button {
                Task {
                    await likesService.toggleLike(track: track)
                }
            } label: {
                Image(systemName: likesService.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                    .foregroundColor(likesService.isLiked(trackId: track.id) ? YMTheme.heartRed : YMTheme.fg40)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .frame(width: 24)

            // Duration
            Text(track.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(YMTheme.fg40)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
        .background(isHovered ? Color.white.opacity(0.04) : (isPlaying ? Color.white.opacity(0.02) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            onPlay()
        }
    }

    @ViewBuilder
    private var shiftBadge: some View {
        if let chart = item.chart {
            switch chart.progress {
            case "up":
                Image(systemName: "triangle.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.green)
            case "down":
                Image(systemName: "triangle.fill")
                    .font(.system(size: 7))
                    .rotationEffect(.degrees(180))
                    .foregroundColor(.red)
            case "new":
                Text("★")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange)
            default:
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(YMTheme.fg40)
            }
        }
    }
}
