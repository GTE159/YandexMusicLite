import SwiftUI

/// Modern native macOS Artist detail view featuring hero banner, popular tracks, discography, and wave launcher.
public struct ArtistDetailView: View {
    public let artistId: String
    public let artistName: String

    @UIState private var briefInfo: YMArtistBriefInfo? = nil
    @UIState private var isLoading = true
    @UIState private var errorMessage: String? = nil

    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var likesService = LikesService.shared
    @UIState private var coordinator = NavigationCoordinator.shared
    private let networkClient = YMNetworkClient.shared

    public init(artistId: String, artistName: String) {
        self.artistId = artistId
        self.artistName = artistName
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                // Top Navigation Bar (Back button + Title)
                HStack(spacing: 12) {
                    Button {
                        coordinator.pop()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Назад")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(YMTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("[", modifiers: .command)

                    Text(artistName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(YMTheme.fg60)

                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка профиля артиста...")
                            .font(.caption)
                            .foregroundStyle(YMTheme.fg40)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else if let error = errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Повторить") {
                            loadArtistData()
                        }
                        .buttonStyle(YMGlassPillButtonStyle(primary: true))
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else if let info = briefInfo {
                    // Hero Banner
                    HStack(spacing: 24) {
                        CachedCoverImage(
                            coverUri: info.artist.coverUri,
                            size: .medium,
                            displaySize: 150,
                            cornerRadius: 75
                        )
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(YMTheme.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(info.artist.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(YMTheme.fg)

                            if let stats = info.stats, !stats.formattedListeners.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                    Text(stats.formattedListeners)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(YMTheme.fg60)
                            }

                            // Actions Bar
                            HStack(spacing: 12) {
                                if !info.popularTracks.isEmpty {
                                    Button {
                                        audioEngine.assignQueue(info.popularTracks, startingAt: 0)
                                    } label: {
                                        Label("Слушать популярное", systemImage: "play.fill")
                                    }
                                    .buttonStyle(YMGlassPillButtonStyle(primary: true, height: 34))
                                }

                                Button {
                                    audioEngine.startWave(forArtist: info.artist)
                                } label: {
                                    Label("Моя волна по артисту", systemImage: "waveform.path.ecg")
                                }
                                .buttonStyle(YMGlassPillButtonStyle(primary: false, height: 34))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Popular Tracks Section
                    if !info.popularTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Популярные треки")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(YMTheme.fg)
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                ForEach(Array(info.popularTracks.prefix(10).enumerated()), id: \.element.id) { index, track in
                                    HStack(spacing: 14) {
                                        // Rank number
                                        Text("\(index + 1)")
                                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                                            .foregroundStyle(index < 3 ? YMTheme.accent : YMTheme.fg40)
                                            .frame(width: 24, alignment: .trailing)

                                        // Play / Waveform indicator
                                        Button {
                                            audioEngine.assignQueue(info.popularTracks, startingAt: index)
                                        } label: {
                                            if audioEngine.currentTrack?.id == track.id && audioEngine.isPlaying {
                                                Image(systemName: "waveform")
                                                    .foregroundColor(YMTheme.accent)
                                                    .font(.system(size: 13))
                                            } else {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(YMTheme.fg80)
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        CachedCoverImage(
                                            coverUri: track.effectiveCoverUri,
                                            size: .small,
                                            displaySize: 34,
                                            cornerRadius: 4
                                        )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.displayTitle)
                                                .font(.system(size: 13, weight: audioEngine.currentTrack?.id == track.id ? .semibold : .regular))
                                                .foregroundStyle(audioEngine.currentTrack?.id == track.id ? YMTheme.accent : YMTheme.fg)
                                                .lineLimit(1)

                                            if let album = track.albums.first {
                                                Button {
                                                    coordinator.navigate(to: .album(id: album.id, title: album.title))
                                                } label: {
                                                    Text(album.title)
                                                        .font(.caption)
                                                        .foregroundStyle(YMTheme.fg40)
                                                        .lineLimit(1)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }

                                        Spacer()

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

                                        Text(track.formattedDuration)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(YMTheme.fg40)
                                            .frame(width: 44, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 24)
                                    .background(audioEngine.currentTrack?.id == track.id ? Color.white.opacity(0.04) : Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        audioEngine.assignQueue(info.popularTracks, startingAt: index)
                                    }
                                }
                            }
                        }
                    }

                    // Direct Albums Section
                    if !info.albums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Альбомы")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(YMTheme.fg)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(info.albums) { album in
                                        YMAlbumCard(album: album) {
                                            // Play album
                                            Task {
                                                if let fullAlbum = try? await networkClient.fetchAlbumWithTracks(albumId: album.id) {
                                                    audioEngine.assignQueue(fullAlbum.allTracks, startingAt: 0)
                                                }
                                            }
                                        } onSelect: {
                                            coordinator.navigate(to: .album(id: album.id, title: album.title))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // Singles & EPs Section
                    if !info.alsoAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Синглы и сборники")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(YMTheme.fg)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(info.alsoAlbums) { album in
                                        YMAlbumCard(album: album) {
                                            Task {
                                                if let fullAlbum = try? await networkClient.fetchAlbumWithTracks(albumId: album.id) {
                                                    audioEngine.assignQueue(fullAlbum.allTracks, startingAt: 0)
                                                }
                                            }
                                        } onSelect: {
                                            coordinator.navigate(to: .album(id: album.id, title: album.title))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // Similar Artists Section
                    if !info.similarArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Похожие исполнители")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(YMTheme.fg)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(info.similarArtists) { similar in
                                        YMArtistCard(artist: similar) {
                                            coordinator.navigate(to: .artist(id: similar.id, name: similar.name))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    // Biography / Description Section
                    if let desc = info.description?.text, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Об исполнителе")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(YMTheme.fg)

                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(YMTheme.fg80)
                                .lineSpacing(4)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: YMTheme.cornerRadiusMedium)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: YMTheme.cornerRadiusMedium).strokeBorder(YMTheme.border, lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 60)
        }
        .ymScreenBackground()
        .task {
            loadArtistData()
        }
    }

    private func loadArtistData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let info = try await networkClient.fetchArtistBriefInfo(artistId: artistId)
                await MainActor.run {
                    self.briefInfo = info
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Не удалось загрузить данные артиста: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
