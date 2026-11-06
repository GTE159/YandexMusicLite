import SwiftUI

public enum SidebarSection: String, CaseIterable, Identifiable {
    case myWave = "Моя волна"
    case chart = "Чарт"
    case favorites = "Мне нравится"
    case playlists = "Плейлисты"
    case search = "Поиск"
    case settings = "Настройки"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .myWave: return "waveform.path.ecg"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .favorites: return "heart.fill"
        case .playlists: return "music.note.list"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

/// Main macOS NavigationSplitView orchestrating the sidebar, NavigationStack, and the Player Bar.
public struct MainSplitView: View {
    @UIState private var selectedSection: SidebarSection? = .myWave
    @UIState private var coordinator = NavigationCoordinator.shared
    @UIState private var authService = AuthService.shared
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var rotorService = RotorService.shared
    @UIState private var likesService = LikesService.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var columnVisibility: NavigationSplitViewVisibility = .automatic

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                // Fixed top spacing to keep sidebar items cleanly below window controls
                Color.clear
                    .frame(height: 52)

                // Sidebar Navigation List
                List(selection: $selectedSection) {
                    Section("Медиатека") {
                        sidebarRow(section: .myWave)
                        sidebarRow(section: .chart, badge: "ТОП-100")
                        sidebarRow(
                            section: .favorites,
                            badge: likesService.likedTrackIds.isEmpty ? nil : "\(likesService.likedTrackIds.count)"
                        )
                        sidebarRow(section: .playlists)
                    }

                    Section("Обзор и настройки") {
                        sidebarRow(section: .search)
                        sidebarRow(section: .settings)
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedSection) {
                    coordinator.popToRoot()
                }

                Spacer()

                // User account card in sidebar footer
                if let user = authService.currentUser {
                    Divider()
                        .padding(.horizontal, 12)

                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(YMTheme.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(YMTheme.fg)
                                .lineLimit(1)

                            if user.hasActiveSubscription {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 9))
                                    Text("Плюс активен")
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundColor(YMTheme.accent)
                            }
                        }

                        Spacer()

                        Button {
                            authService.signOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13))
                                .foregroundStyle(YMTheme.fg40)
                        }
                        .buttonStyle(.plain)
                        .help("Выйти из аккаунта")
                    }
                    .padding(14)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                NavigationStack(path: $coordinator.path) {
                    Group {
                        switch selectedSection {
                        case .myWave:
                            MyWaveView()
                        case .chart:
                            ChartView()
                        case .favorites:
                            FavoritesListView()
                        case .playlists:
                            PlaylistsView()
                        case .search:
                            SearchView()
                        case .settings:
                            SettingsView()
                        case .none:
                            Text("Выберите раздел")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .artist(let id, let name):
                            ArtistDetailView(artistId: id, artistName: name)
                        case .album(let id, let title):
                            AlbumDetailView(albumId: id, albumTitle: title)
                        }
                    }
                }

                PlayerBarView()
            }
            .ignoresSafeArea(.container, edges: .top)
            .navigationTitle("")
            .toolbar(.hidden, for: .windowToolbar)
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            setupRotorAudioHooks()
        }
    }

    @ViewBuilder
    private func sidebarRow(section: SidebarSection, badge: String? = nil) -> some View {
        NavigationLink(value: section) {
            HStack {
                Label {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                } icon: {
                    Image(systemName: section.iconName)
                        .foregroundColor(
                            section == .favorites ? YMTheme.heartRed :
                            (section == .chart ? YMTheme.accent : (selectedSection == section ? YMTheme.accent : .primary))
                        )
                }

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .foregroundStyle(YMTheme.fg60)
                }
            }
        }
    }

    private func setupRotorAudioHooks() {
        // Connect AudioPlayerEngine events with RotorService telemetry
        audioEngine.onTrackStarted = { track in
            Task {
                try? await rotorService.sendTrackStarted(track: track)
            }
        }

        audioEngine.onTrackFinished = { track, totalSeconds in
            Task {
                try? await rotorService.sendTrackFinished(track: track, totalPlayedSeconds: totalSeconds)
            }
        }

        audioEngine.onTrackSkipped = { track, playedSeconds in
            Task {
                try? await rotorService.sendTrackSkipped(track: track, playedSeconds: playedSeconds)
            }
        }

        audioEngine.onStartCustomWaveRequested = { [weak audioEngine] context, vibe in
            Task { @MainActor in
                self.selectedSection = .myWave
                guard let audioEngine = audioEngine else { return }
                do {
                    let tracks = try await rotorService.startWave(context: context, vibe: vibe)
                    audioEngine.activeWaveContext = context
                    audioEngine.activeWaveVibe = vibe ?? .defaultWave
                    audioEngine.isWaveMode = true
                    audioEngine.setQueue(tracks, startingAt: 0)
                } catch {
                    print("[MainSplitView] Failed custom wave: \(error)")
                }
            }
        }

        // Fetch next batch only if wave mode is active
        audioEngine.onQueueNeedsMoreTracks = {
            Task { @MainActor in
                guard audioEngine.isWaveMode else { return }
                if let lastTrack = audioEngine.queue.last {
                    let history = audioEngine.queue.suffix(25).map(\.rotorTrackIdentifier)
                    if let nextTracks = try? await rotorService.fetchNextBatch(
                        lastTrackId: lastTrack.rotorTrackIdentifier,
                        queueHistory: history
                    ), !nextTracks.isEmpty {
                        let existingIds = Set(audioEngine.queue.map(\.id))
                        let uniqueNew = nextTracks.filter { !existingIds.contains($0.id) }
                        audioEngine.appendToQueue(uniqueNew)
                    }
                }
            }
        }

        // Wire system remote like command to current track
        RemoteCommandManager.shared.onLikeToggled = {
            Task { @MainActor in
                if let track = audioEngine.currentTrack {
                    await likesService.toggleLike(track: track)
                }
            }
        }
    }
}
