import SwiftUI

/// Modern, beautiful "Мне нравится" (Favorites) view featuring iconic gradient hero banner,
/// quick play/shuffle/wave actions, glass search filter, and tracklist table.
public struct FavoritesListView: View {
    @UIState private var likesService = LikesService.shared
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var coordinator = NavigationCoordinator.shared

    @UIState private var isLoading = false
    @UIState private var errorMessage: String? = nil
    @UIState private var filterQuery = ""

    public init() {}

    private var displayedTracks: [YMTrack] {
        let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return likesService.likedTracks }
        return likesService.searchInLikes(query: q)
    }

    private var totalDurationFormatted: String {
        let totalMs = displayedTracks.compactMap(\.durationMs).reduce(0, +)
        guard totalMs > 0 else { return "" }
        let totalSeconds = totalMs / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        }
        return "\(minutes) мин"
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    // Hero Banner
                    HStack(alignment: .bottom, spacing: 24) {
                        // Iconic Gradient Heart Tile
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 255 / 255, green: 75 / 255, blue: 43 / 255),
                                            Color(red: 255 / 255, green: 65 / 255, blue: 108 / 255),
                                            Color(red: 142 / 255, green: 45 / 255, blue: 226 / 255)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 150, height: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.red.opacity(0.35), radius: 24, y: 10)

                            Image(systemName: "heart.fill")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        }

                        // Metadata & Actions
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ПЛЕЙЛИСТ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(YMTheme.fg40)
                                .tracking(1.2)

                            Text("Мне нравится")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(YMTheme.fg)

                            HStack(spacing: 6) {
                                Text("\(likesService.likedTrackIds.count) треков")
                                if !totalDurationFormatted.isEmpty {
                                    Text("· \(totalDurationFormatted)")
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(YMTheme.fg60)

                            // Actions Bar
                            HStack(spacing: 12) {
                                Button {
                                    let playable = displayedTracks.filter { !$0.isPlaceholder && !$0.isSpacer }
                                    if !playable.isEmpty {
                                        audioEngine.isWaveMode = false
                                        audioEngine.setQueue(playable, startingAt: 0)
                                    }
                                } label: {
                                    Label("Слушать всё", systemImage: "play.fill")
                                }
                                .buttonStyle(YMGlassPillButtonStyle(primary: true, height: 34))

                                Button {
                                    if !filterQuery.isEmpty {
                                        audioEngine.playShuffled(displayedTracks)
                                    } else {
                                        Task {
                                            let randomTracks = await likesService.fetchRandomLikedTracksForShuffle(limit: 50)
                                            audioEngine.playShuffled(randomTracks)
                                        }
                                    }
                                } label: {
                                    Label("Перемешать", systemImage: "shuffle")
                                }
                                .buttonStyle(YMGlassPillButtonStyle(primary: false, height: 34))

                                Button {
                                    let playable = displayedTracks.filter { !$0.isPlaceholder && !$0.isSpacer }
                                    audioEngine.startWave(forPlaylist: YMPlaylist(uid: "user", kind: 3, title: "Мне нравится"), tracks: Array(playable))
                                } label: {
                                    Label("Волна по любимому", systemImage: "waveform.path.ecg")
                                }
                                .buttonStyle(YMGlassPillButtonStyle(primary: false, height: 34))
                            }
                            .padding(.top, 4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Search & Filter Input Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(YMTheme.fg40)

                        TextField("Поиск в понравившихся треках...", text: $filterQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))

                        if !filterQuery.isEmpty {
                            Text("\(displayedTracks.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(YMTheme.fg40)

                            Button {
                                filterQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(YMTheme.fg40)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(YMTheme.border, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)

                    Divider()
                        .padding(.horizontal, 24)

                    // Tracklist
                    if likesService.likedTrackIds.isEmpty && !isLoading {
                        VStack(spacing: 14) {
                            Image(systemName: "heart")
                                .font(.system(size: 44))
                                .foregroundStyle(YMTheme.fg40)
                            Text("Здесь будут ваши любимые треки")
                                .font(.headline)
                                .foregroundStyle(YMTheme.fg)
                            Text("Нажимайте на сердечко у любых треков, чтобы собрать свою коллекцию")
                                .font(.subheadline)
                                .foregroundStyle(YMTheme.fg60)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        TrackTableView(
                            tracks: displayedTracks,
                            onPlayTrack: { track in
                                audioEngine.isWaveMode = false
                                if let idx = displayedTracks.firstIndex(where: { $0.id == track.id }) {
                                    audioEngine.setQueue(displayedTracks, startingAt: idx)
                                }
                            },
                            onTrackAppear: { track in
                                if track.isPlaceholder {
                                    likesService.loadBatchIfNeeded(forTrackId: track.id)
                                }
                            },
                            onLoadMore: {
                                Task {
                                    await likesService.loadMoreLikedTracks()
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ymScreenBackground()
        .task {
            if likesService.likedTrackIds.isEmpty {
                try? await likesService.syncLikes()
            }
        }
    }
}
