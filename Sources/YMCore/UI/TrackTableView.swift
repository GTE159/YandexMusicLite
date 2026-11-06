import SwiftUI

/// High-performance native macOS Table for track lists.
/// Far more memory-efficient than LazyVStack for lists with thousands of items.
public struct TrackTableView: View {
    let tracks: [YMTrack]
    let onPlayTrack: (YMTrack) -> Void
    var onTrackAppear: ((YMTrack) -> Void)? = nil
    var onLoadMore: (() -> Void)? = nil

    @UIState private var selectedTrackId: YMTrack.ID?
    @UIState private var likesService = LikesService.shared
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var coordinator = NavigationCoordinator.shared

    public init(
        tracks: [YMTrack],
        onPlayTrack: @escaping (YMTrack) -> Void,
        onTrackAppear: ((YMTrack) -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil
    ) {
        self.tracks = tracks
        self.onPlayTrack = onPlayTrack
        self.onTrackAppear = onTrackAppear
        self.onLoadMore = onLoadMore
    }

    private var tableTracks: [YMTrack] {
        tracks
    }

    public var body: some View {
        Table(tableTracks, selection: $selectedTrackId) {
            // Column 1: Play state & Like button
            TableColumn("") { track in
                Group {
                    if track.isSpacer {
                        Color.clear.frame(width: 44, height: 32)
                    } else if track.isPlaceholder {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 12, height: 12)
                        }
                        .frame(width: 44, alignment: .leading)
                    } else {
                        HStack(spacing: 8) {
                            if audioEngine.currentTrack?.id == track.id && audioEngine.isPlaying {
                                Image(systemName: "waveform")
                                    .foregroundStyle(YMTheme.accent)
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Button {
                                    onPlayTrack(track)
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(YMTheme.fg60)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                Task {
                                    await likesService.toggleLike(track: track)
                                }
                            } label: {
                                Image(systemName: likesService.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                                    .foregroundColor(likesService.isLiked(trackId: track.id) ? YMTheme.heartRed : YMTheme.fg40)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 44, alignment: .leading)
                    }
                }
                .onAppear {
                    guard !track.isSpacer else { return }
                    onTrackAppear?(track)
                    if !track.isPlaceholder, tracks.suffix(5).contains(where: { $0.id == track.id }) {
                        onLoadMore?()
                    }
                }
            }
            .width(44)

            // Column 2: Album Cover thumbnail
            TableColumn("Обложка") { track in
                if track.isSpacer {
                    Color.clear.frame(width: 32, height: 32)
                } else if track.isPlaceholder {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 32, height: 32)
                } else {
                    CachedCoverImage(
                        coverUri: track.effectiveCoverUri,
                        size: .small,
                        displaySize: 32,
                        cornerRadius: 4
                    )
                }
            }
            .width(36)

            // Column 3: Track Title & Version
            TableColumn("Название") { track in
                if track.isSpacer {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 32)
                } else if track.isPlaceholder {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 140, height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(track.displayTitle)
                        .font(.system(size: 13, weight: audioEngine.currentTrack?.id == track.id ? .semibold : .regular))
                        .foregroundStyle(audioEngine.currentTrack?.id == track.id ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                }
            }
            .width(min: 110, ideal: 220)

            // Column 4: Artist(s)
            TableColumn("Исполнитель") { track in
                if track.isSpacer {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 32)
                } else if track.isPlaceholder {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 100, height: 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let firstArtist = track.artists.first {
                    Button {
                        coordinator.navigate(to: .artist(id: firstArtist.id, name: firstArtist.name))
                    } label: {
                        Text(track.artistsString)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(track.artistsString)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 80, ideal: 160)

            // Column 5: Album
            TableColumn("Альбом") { track in
                if track.isSpacer {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 32)
                } else if track.isPlaceholder {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 80, height: 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let firstAlbum = track.albums.first {
                    Button {
                        coordinator.navigate(to: .album(id: firstAlbum.id, title: firstAlbum.title))
                    } label: {
                        Text(firstAlbum.title)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("-")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 60, ideal: 140)

            // Column 6: Duration
            TableColumn("Время") { track in
                if track.isSpacer {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 32)
                } else if track.isPlaceholder {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 30, height: 10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text(track.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .width(46)
        }
        .contextMenu(forSelectionType: YMTrack.ID.self) { selection in
            if let selectedId = selection.first, let track = tracks.first(where: { $0.id == selectedId }), !track.isPlaceholder, !track.isSpacer {
                Button("Воспроизвести") {
                    onPlayTrack(track)
                }
                Button(likesService.isLiked(trackId: track.id) ? "Удалить из «Мне нравится»" : "Добавить в «Мне нравится»") {
                    Task {
                        await likesService.toggleLike(track: track)
                    }
                }
                Button {
                    audioEngine.startWave(forTrack: track)
                } label: {
                    Label("Запустить Мою волну по треку", systemImage: "waveform.badge.magnifyingglass")
                }

                Divider()

                if let firstArtist = track.artists.first {
                    Button {
                        coordinator.navigate(to: .artist(id: firstArtist.id, name: firstArtist.name))
                    } label: {
                        Label("Перейти к исполнителю (\(firstArtist.name))", systemImage: "person.circle")
                    }
                }

                if let firstAlbum = track.albums.first {
                    Button {
                        coordinator.navigate(to: .album(id: firstAlbum.id, title: firstAlbum.title))
                    } label: {
                        Label("Перейти к альбому (\(firstAlbum.title))", systemImage: "opticaldisc")
                    }
                }

                Button {
                    audioEngine.assignQueue([track], startingAt: 0)
                    coordinator.isLyricsPresented = true
                } label: {
                    Label("Показать текст песни", systemImage: "quote.bubble")
                }

                if audioEngine.isWaveMode {
                    Divider()
                    Button {
                        audioEngine.applyWaveTuning(.moreLikeThis, for: track)
                    } label: {
                        Label("Больше похожих треков", systemImage: "flame")
                    }
                    Button {
                        audioEngine.applyWaveTuning(.lessLikeThis, for: track)
                    } label: {
                        Label("Меньше таких треков", systemImage: "hand.thumbsdown")
                    }
                }
            }
        } primaryAction: { selection in
            if let selectedId = selection.first, let track = tracks.first(where: { $0.id == selectedId }), !track.isSpacer {
                onPlayTrack(track)
            }
        }
    }
}
