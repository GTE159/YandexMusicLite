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

/// Main macOS NavigationSplitView containing Sidebar, dynamic Detail Views with Tables,
/// and the isolated Player Bar pinned to the bottom.
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
                // Fixed top spacing to keep sidebar items cleanly below traffic lights and screen top
                Color.clear
                    .frame(height: 50)

                List(SidebarSection.allCases, selection: $selectedSection) { section in
                    NavigationLink(value: section) {
                        Label {
                            Text(section.rawValue)
                        } icon: {
                            Image(systemName: section.iconName)
                                .foregroundColor(section == .favorites ? .red : (section == .chart ? .orange : .primary))
                        }
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
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tint)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)

                            if user.hasActiveSubscription {
                                Text("Плюс активен")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        Button {
                            authService.signOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Выйти из аккаунта")
                    }
                    .padding(12)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
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
        .frame(minWidth: 480, minHeight: 380)
        .onAppear {
            setupRotorAudioHooks()
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

// MARK: - 1. Моя волна View

public struct MyWaveView: View {
    @UIState private var waveTracks: [YMTrack] = []
    @UIState private var rotorService = RotorService.shared
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var isLoadingWave = false
    @UIState private var isLoadingMoreWave = false
    @UIState private var errorMessage: String? = nil
    @UIState private var toastMessage: String? = nil
    @UIState private var toastDismissTask: Task<Void, Never>? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Wave Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioEngine.activeWaveContext.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                    if !windowState.isCompactWidth {
                        Text(audioEngine.activeWaveContext.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if audioEngine.activeWaveContext != .myWaveDefault {
                    Button {
                        startWave(context: .myWaveDefault, vibe: .defaultWave)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            if !windowState.isCompactWidth {
                                Text("Сбросить к Моей волне")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Вернуться к стандартной Моей волне")
                }

                Button {
                    startWave(context: audioEngine.activeWaveContext, vibe: audioEngine.activeWaveVibe)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                        Text(audioEngine.isPlaying && audioEngine.isWaveMode ? "Перезапустить волну" : "Запустить волну")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingWave)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Vibe Presets & Tuning Toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Vibe Presets Chips
                    ForEach(YMWaveVibePreset.allCases) { preset in
                        let isSelected = audioEngine.activeWaveVibe == preset
                        Button {
                            guard audioEngine.activeWaveVibe != preset || !audioEngine.isWaveMode else { return }
                            audioEngine.activeWaveVibe = preset
                            startWave(context: audioEngine.activeWaveContext, vibe: preset)
                            showToast("Характер волны: \(preset.title)")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 11))
                                Text(preset.title)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }

                    if audioEngine.isWaveMode, let track = audioEngine.currentTrack {
                        Divider()
                            .frame(height: 18)
                            .padding(.horizontal, 2)

                        Button {
                            audioEngine.applyWaveTuning(.moreLikeThis)
                            showToast("Алгоритм учёл: больше треков в стиле «\(track.displayTitle)»")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flame")
                                    .font(.system(size: 11))
                                Text("Больше похожих")
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Усилить этот стиль в волне")

                        Button {
                            let trackTitle = track.displayTitle
                            audioEngine.applyWaveTuning(.lessLikeThis)
                            showToast("Алгоритм учёл: меньше треков в стиле «\(trackTitle)»")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsdown")
                                    .font(.system(size: 11))
                                Text("Меньше таких")
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Пропустить и реже ставить такое")

                        Button {
                            audioEngine.applyWaveTuning(.moreDiversity)
                            showToast("Алгоритм учёл: перенастройка на большее разнообразие")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("Больше разнообразия")
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Сменить вектор и добавить незнакомых треков")
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 8)

            // Feedback Confirmation Toast / Badge
            if let toast = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text(toast)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            Divider()

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Ошибка загрузки волны: \(error)")
                        .font(.callout)
                        .foregroundColor(.red)
                    Spacer()
                    Button("Повторить") {
                        startWave()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
            }

            if isLoadingWave && waveTracks.isEmpty {
                Spacer()
                ProgressView("Загрузка Моей волны...")
                Spacer()
            } else if waveTracks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Нажмите «Запустить волну», чтобы начать персональное воспроизведение")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                TrackTableView(
                    tracks: waveTracks,
                    onPlayTrack: { track in
                        audioEngine.isWaveMode = true
                        if let index = waveTracks.firstIndex(where: { $0.id == track.id }) {
                            if audioEngine.queue != waveTracks {
                                audioEngine.setQueue(waveTracks, startingAt: index)
                            } else {
                                audioEngine.playTrack(at: index)
                            }
                        }
                    },
                    onLoadMore: {
                        guard !isLoadingWave && !isLoadingMoreWave, let lastTrack = waveTracks.last else { return }
                        isLoadingMoreWave = true
                        let history = waveTracks.suffix(25).map(\.rotorTrackIdentifier)
                        Task {
                            defer {
                                Task { @MainActor in
                                    isLoadingMoreWave = false
                                }
                            }
                            if let next = try? await rotorService.fetchNextBatch(
                                lastTrackId: lastTrack.rotorTrackIdentifier,
                                queueHistory: history
                            ), !next.isEmpty {
                                await MainActor.run {
                                    let existingIds = Set(waveTracks.map(\.id))
                                    let uniqueNext = next.filter { !existingIds.contains($0.id) }
                                    guard !uniqueNext.isEmpty else { return }
                                    if audioEngine.isWaveMode {
                                        let queueIds = Set(audioEngine.queue.map(\.id))
                                        let uniqueForQueue = uniqueNext.filter { !queueIds.contains($0.id) }
                                        if !uniqueForQueue.isEmpty {
                                            audioEngine.appendToQueue(uniqueForQueue)
                                        }
                                    } else {
                                        waveTracks.append(contentsOf: uniqueNext)
                                    }
                                }
                            }
                        }
                    }
                )
            }
        }
        .onChange(of: audioEngine.queue) { _, newQueue in
            if audioEngine.isWaveMode && !newQueue.isEmpty && waveTracks != newQueue {
                waveTracks = newQueue
            }
        }
        .task {
            if waveTracks.isEmpty {
                if audioEngine.isWaveMode && !audioEngine.queue.isEmpty {
                    // Восстанавливаем уже играющую волну без перезапуска
                    waveTracks = audioEngine.queue
                }
            }
        }
    }

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func startWave(context: YMWaveContext? = nil, vibe: YMWaveVibePreset? = nil) {
        let targetContext = context ?? audioEngine.activeWaveContext
        let targetVibe = vibe ?? audioEngine.activeWaveVibe

        self.isLoadingWave = true
        self.errorMessage = nil

        Task {
            do {
                let tracks = try await rotorService.startWave(context: targetContext, vibe: targetVibe)
                await MainActor.run {
                    self.isLoadingWave = false
                    self.errorMessage = nil
                    self.waveTracks = tracks
                    self.audioEngine.activeWaveContext = targetContext
                    self.audioEngine.activeWaveVibe = targetVibe
                    self.audioEngine.isWaveMode = true
                    self.audioEngine.setQueue(tracks, startingAt: 0)
                }
            } catch {
                await MainActor.run {
                    self.isLoadingWave = false
                    self.errorMessage = error.localizedDescription
                    print("[MyWaveView] Failed to start wave: \(error)")
                }
            }
        }
    }
}

// MARK: - 2. Мне нравится View

public struct FavoritesListView: View {
    @UIState private var likesService = LikesService.shared
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var windowState = WindowState.shared
    @UIState private var isLoading = false
    @UIState private var errorMessage: String? = nil
    @UIState private var filterQuery = ""

    private var displayedTracks: [YMTrack] {
        let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return likesService.likedTracks }
        return likesService.searchInLikes(query: q)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Мне нравится")
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                    if !filterQuery.isEmpty {
                        Text("\(displayedTracks.count) из \(likesService.likedTrackIds.count) треков")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(likesService.likedTrackIds.count) понравившихся треков")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if !displayedTracks.isEmpty {
                    Button {
                        let playable = displayedTracks.filter { !$0.isPlaceholder && !$0.isSpacer }
                        if !playable.isEmpty {
                            audioEngine.isWaveMode = false
                            audioEngine.setQueue(playable, startingAt: 0)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            if !windowState.isCompactWidth {
                                Text("Слушать")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Слушать")

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
                        HStack(spacing: 4) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 10))
                            if !windowState.isCompactWidth {
                                Text("Перемешать")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Перемешать")
                }

                Button {
                    loadLikedTracks()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Обновить")
                .disabled(isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Personal Search Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))

                    TextField("Поиск по моим трекам, исполнителям и альбомам...", text: $filterQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                    if likesService.isIndexingCatalog {
                        ProgressView()
                            .controlSize(.small)
                            .help("Индексация всех треков для мгновенного поиска...")
                    }

                    if !filterQuery.isEmpty {
                        Button {
                            filterQuery = ""
                            likesService.pruneSearchCatalogIfNeeded()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if likesService.isIndexingCatalog {
                    Text("Индексация всех треков (\(likesService.likedTracks.count) из \(likesService.likedTrackIds.count))...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                    Spacer()
                    Button("Повторить") {
                        loadLikedTracks()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
            }

            if isLoading && likesService.likedTracks.isEmpty {
                Spacer()
                ProgressView("Загрузка понравившихся треков...")
                Spacer()
            } else if likesService.likedTracks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Любимые треки появятся здесь")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if displayedTracks.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("В избранном ничего не найдено")
                        .font(.headline)
                    Text("По запросу «\(filterQuery)» треков не найдено")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Очистить поиск") {
                        filterQuery = ""
                        likesService.pruneSearchCatalogIfNeeded()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                Spacer()
            } else {
                TrackTableView(
                    tracks: displayedTracks,
                    onPlayTrack: { track in
                        audioEngine.isWaveMode = false
                        if track.isPlaceholder {
                            Task {
                                if let loaded = await likesService.fetchTrackImmediately(trackId: track.id) {
                                    let playable = displayedTracks.map { $0.id == loaded.id ? loaded : $0 }.filter { !$0.isPlaceholder }
                                    if let idx = playable.firstIndex(where: { $0.id == loaded.id }) {
                                        audioEngine.setQueue(playable, startingAt: idx)
                                    }
                                }
                            }
                        } else {
                            let playable = displayedTracks.filter { !$0.isPlaceholder }
                            if let idx = playable.firstIndex(where: { $0.id == track.id }) {
                                audioEngine.setQueue(playable, startingAt: idx)
                            }
                        }
                    },
                    onTrackAppear: { track in
                        if filterQuery.isEmpty && track.isPlaceholder {
                            likesService.loadBatchIfNeeded(forTrackId: track.id)
                        }
                    },
                    onLoadMore: {
                        if filterQuery.isEmpty {
                            Task {
                                await likesService.loadMoreLikedTracks()
                            }
                        }
                    }
                )

                if likesService.isLoadingMore && filterQuery.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Подгрузка следующих треков...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .task {
            if likesService.likedTracks.isEmpty {
                loadLikedTracks()
            }
        }
        .task(id: filterQuery) {
            let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                await likesService.ensureAllLikedTracksLoadedForSearch()
            } else {
                likesService.pruneSearchCatalogIfNeeded()
            }
        }
    }

    private func loadLikedTracks() {
        self.isLoading = true
        self.errorMessage = nil

        Task {
            do {
                _ = try await likesService.fetchLikedTracks(initialLimit: 50)
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Не удалось загрузить треки: \(error.localizedDescription)"
                    print("[FavoritesListView] Error: \(error)")
                }
            }
        }
    }
}

// MARK: - 3. Плейлисты View

public struct PlaylistsView: View {
    @UIState private var playlists: [YMPlaylist] = []
    @UIState private var selectedPlaylist: YMPlaylist? = nil
    @UIState private var playlistTracks: [YMTrack] = []
    @UIState private var isLoadingPlaylists = false
    @UIState private var isLoadingTracks = false
    @UIState private var errorMessage: String? = nil
    @UIState private var playlistFilterQuery: String = ""

    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var windowState = WindowState.shared
    private let networkClient = YMNetworkClient.shared
    private let keychain = KeychainManager.shared

    private var displayedPlaylistTracks: [YMTrack] {
        let q = playlistFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return playlistTracks }
        return playlistTracks.filter { track in
            track.displayTitle.lowercased().contains(q) ||
            track.artistsString.lowercased().contains(q) ||
            (track.primaryAlbumTitle?.lowercased().contains(q) ?? false)
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if let playlist = selectedPlaylist {
                // Playlist Detail Mode
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        Button {
                            selectedPlaylist = nil
                            playlistTracks = []
                            playlistFilterQuery = ""
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                if !windowState.isCompactWidth {
                                    Text("Плейлисты")
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        CachedCoverImage(
                            coverUri: playlist.coverUri,
                            size: .medium,
                            displaySize: 48,
                            cornerRadius: 6
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.title)
                                .font(.title3.weight(.bold))
                                .lineLimit(1)
                            if !playlistFilterQuery.isEmpty {
                                Text("\(displayedPlaylistTracks.count) из \(playlistTracks.count) треков")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let count = playlist.trackCount {
                                Text("\(count) треков")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if !displayedPlaylistTracks.isEmpty {
                            HStack(spacing: 8) {
                                Button {
                                    audioEngine.isWaveMode = false
                                    audioEngine.setQueue(displayedPlaylistTracks, startingAt: 0)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text(windowState.isCompactWidth ? "Слушать" : "Слушать всё")
                                    }
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    audioEngine.playShuffled(displayedPlaylistTracks)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "shuffle")
                                        if !windowState.isCompactWidth {
                                            Text("Перемешать")
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .help("Перемешать")

                                Button {
                                    audioEngine.startWave(forPlaylist: playlist, tracks: playlistTracks)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "waveform")
                                        if !windowState.isCompactWidth {
                                            Text("Волна по плейлисту")
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .help("Волна по плейлисту")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    // Personal Search Bar in Playlist
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))

                        TextField("Поиск по трекам, артистам и альбомам плейлиста...", text: $playlistFilterQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))

                        if !playlistFilterQuery.isEmpty {
                            Button {
                                playlistFilterQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    Divider()

                    if isLoadingTracks && playlistTracks.isEmpty {
                        Spacer()
                        ProgressView("Загрузка треков плейлиста...")
                        Spacer()
                    } else if playlistTracks.isEmpty {
                        Spacer()
                        Text("В этом плейлисте пока нет треков")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else if displayedPlaylistTracks.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("В плейлисте ничего не найдено")
                                .font(.headline)
                            Text("По запросу «\(playlistFilterQuery)» ничего не найдено")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Очистить поиск") {
                                playlistFilterQuery = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                        Spacer()
                    } else {
                        TrackTableView(
                            tracks: displayedPlaylistTracks,
                            onPlayTrack: { track in
                                audioEngine.isWaveMode = false
                                if let idx = displayedPlaylistTracks.firstIndex(where: { $0.id == track.id }) {
                                    audioEngine.setQueue(displayedPlaylistTracks, startingAt: idx)
                                }
                            }
                        )
                    }
                }
            } else {
                // Playlists Grid/List Mode
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Плейлисты")
                                .font(.title2.weight(.bold))
                                .lineLimit(1)
                            Text("Ваша коллекция плейлистов")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()

                        Button {
                            loadPlaylists()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Обновить")
                        .disabled(isLoadingPlaylists)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    Divider()

                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                            Spacer()
                            Button("Повторить") {
                                loadPlaylists()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                    }

                    if isLoadingPlaylists && playlists.isEmpty {
                        Spacer()
                        ProgressView("Загрузка плейлистов...")
                        Spacer()
                    } else if playlists.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Плейлисты не найдены")
                                .font(.headline)
                            Text("Созданные вами плейлисты появятся в этом разделе")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        let cardSize: CGFloat = windowState.isCompactWidth ? 120 : 150
                        let gridSpacing: CGFloat = windowState.isCompactWidth ? 12 : 20
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: cardSize, maximum: 190), spacing: gridSpacing)], spacing: gridSpacing) {
                                ForEach(playlists) { playlist in
                                    Button {
                                        selectPlaylist(playlist)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            CachedCoverImage(
                                                coverUri: playlist.coverUri,
                                                size: .medium,
                                                displaySize: cardSize,
                                                cornerRadius: 8
                                            )

                                            Text(playlist.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                                .foregroundColor(.primary)

                                            if let count = playlist.trackCount {
                                                Text("\(count) треков")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(width: cardSize)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            playPlaylistImmediately(playlist, shuffle: false, startWave: false)
                                        } label: {
                                            Label("Слушать", systemImage: "play.fill")
                                        }

                                        Button {
                                            playPlaylistImmediately(playlist, shuffle: true, startWave: false)
                                        } label: {
                                            Label("Перемешать", systemImage: "shuffle")
                                        }

                                        Button {
                                            playPlaylistImmediately(playlist, shuffle: false, startWave: true)
                                        } label: {
                                            Label("Запустить волну по плейлисту", systemImage: "waveform")
                                        }
                                    }
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
        }
        .task {
            if playlists.isEmpty {
                loadPlaylists()
            }
        }
    }

    private func playPlaylistImmediately(_ playlist: YMPlaylist, shuffle: Bool = false, startWave: Bool = false) {
        Task {
            do {
                let details = try await networkClient.fetchPlaylistDetails(uid: playlist.uid, kind: playlist.kind)
                var resolvedTracks: [YMTrack] = []
                if let shorts = details.tracks, !shorts.isEmpty {
                    let fullInShorts = shorts.compactMap(\.track)
                    if fullInShorts.count == shorts.count {
                        resolvedTracks = fullInShorts
                    } else {
                        let ids = shorts.map(\.id)
                        resolvedTracks = try await networkClient.fetchTracks(trackIds: ids)
                    }
                }
                guard !resolvedTracks.isEmpty else { return }
                await MainActor.run {
                    if startWave {
                        audioEngine.startWave(forPlaylist: playlist, tracks: resolvedTracks)
                    } else if shuffle {
                        audioEngine.playShuffled(resolvedTracks)
                    } else {
                        audioEngine.isWaveMode = false
                        audioEngine.setQueue(resolvedTracks, startingAt: 0)
                    }
                }
            } catch {
                print("[PlaylistsView] Context menu action failed: \(error)")
            }
        }
    }

    private func loadPlaylists() {
        guard let uid = keychain.getUserId() else { return }
        self.isLoadingPlaylists = true
        self.errorMessage = nil

        Task {
            do {
                let fetched = try await networkClient.fetchUserPlaylists(uid: uid)
                await MainActor.run {
                    self.playlists = fetched
                    self.isLoadingPlaylists = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingPlaylists = false
                    self.errorMessage = "Ошибка загрузки плейлистов: \(error.localizedDescription)"
                    print("[PlaylistsView] Error: \(error)")
                }
            }
        }
    }

    private func selectPlaylist(_ playlist: YMPlaylist) {
        self.selectedPlaylist = playlist
        self.isLoadingTracks = true
        self.playlistTracks = []
        self.playlistFilterQuery = ""

        Task {
            do {
                let details = try await networkClient.fetchPlaylistDetails(uid: playlist.uid, kind: playlist.kind)
                var resolvedTracks: [YMTrack] = []

                if let shorts = details.tracks, !shorts.isEmpty {
                    let fullInShorts = shorts.compactMap(\.track)
                    if fullInShorts.count == shorts.count {
                        resolvedTracks = fullInShorts
                    } else {
                        let ids = shorts.map(\.id)
                        resolvedTracks = try await networkClient.fetchTracks(trackIds: ids)
                    }
                }

                await MainActor.run {
                    self.playlistTracks = resolvedTracks
                    self.isLoadingTracks = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingTracks = false
                    print("[PlaylistsView] Failed loading tracks: \(error)")
                }
            }
        }
    }
}

// MARK: - 4. Поиск View

public struct SearchView: View {
    @UIState private var searchText = ""
    @UIState private var searchResults: [YMTrack] = []
    @UIState private var isSearching = false
    @UIState private var hasSearched = false
    @UIState private var errorMessage: String? = nil
    @UIState private var currentPage = 0
    @UIState private var canLoadMore = true
    @UIState private var isLoadingMore = false

    @UIState private var audioEngine = AudioPlayerEngine.shared
    private let networkClient = YMNetworkClient.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Поиск треков, артистов и альбомов", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        hasSearched = false
                        errorMessage = nil
                        currentPage = 0
                        canLoadMore = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
            }

            if isSearching && searchResults.isEmpty {
                Spacer()
                ProgressView("Поиск треков...")
                Spacer()
            } else if searchResults.isEmpty {
                Spacer()
                if hasSearched && errorMessage == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Ничего не найдено")
                            .font(.headline)
                        Text("Попробуйте изменить поисковый запрос")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if errorMessage == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "music.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Поиск Яндекс Музыки")
                            .font(.headline)
                        Text("Введите название трека или имя исполнителя")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            } else {
                TrackTableView(
                    tracks: searchResults,
                    onPlayTrack: { track in
                        audioEngine.isWaveMode = false
                        if let idx = searchResults.firstIndex(where: { $0.id == track.id }) {
                            audioEngine.setQueue(searchResults, startingAt: idx)
                        }
                    },
                    onLoadMore: {
                        Task {
                            await loadMoreSearchResults()
                        }
                    }
                )

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Загрузка следующих результатов...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .task(id: searchText) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                searchResults = []
                hasSearched = false
                isSearching = false
                currentPage = 0
                canLoadMore = true
                return
            }

            // Debounce 400ms to avoid unnecessary network load
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
            } catch {
                return // Keystroke cancelled previous task
            }

            isSearching = true
            currentPage = 0
            errorMessage = nil
            do {
                let tracks = try await networkClient.searchTracks(query: query, page: 0)
                if tracks.isEmpty {
                    let localMatches = LikesService.shared.searchInLikes(query: query)
                    self.searchResults = localMatches
                } else {
                    self.searchResults = tracks
                }
                self.hasSearched = true
                self.canLoadMore = tracks.count >= 20
                self.isSearching = false
                self.errorMessage = nil
            } catch {
                if !Task.isCancelled {
                    let localMatches = LikesService.shared.searchInLikes(query: query)
                    if !localMatches.isEmpty {
                        self.searchResults = localMatches
                        self.hasSearched = true
                        self.canLoadMore = false
                        self.isSearching = false
                        self.errorMessage = nil
                    } else {
                        self.isSearching = false
                        self.errorMessage = error.localizedDescription
                        print("[SearchView] Search error: \(error)")
                    }
                }
            }
        }
    }

    private func loadMoreSearchResults() async {
        guard !isSearching && !isLoadingMore && canLoadMore else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        self.isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let nextTracks = try await networkClient.searchTracks(query: query, page: nextPage)
            self.currentPage = nextPage
            self.searchResults.append(contentsOf: nextTracks)
            self.canLoadMore = nextTracks.count >= 20
            self.isLoadingMore = false
        } catch {
            self.isLoadingMore = false
            print("[SearchView] Error loading page \(nextPage): \(error)")
        }
    }
}

// MARK: - 5. Настройки View

public struct SettingsView: View {
    @UIState private var audioEngine = AudioPlayerEngine.shared
    @UIState private var authService = AuthService.shared
    @UIState private var isCacheCleared = false
    @UIState private var isMemoryCompressed = false
    private let networkClient = YMNetworkClient.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Настройки")
                        .font(.title2.weight(.bold))
                    Text("Параметры качества аудиопотока, кодеков и приложения")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Section 1: Качество аудиопотока (все варианты)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Качество аудиопотока")
                        .font(.headline)

                    Text("Выберите уровень качества стриминга. При смене качества текущий воспроизводимый трек перезапустится с текущей секунды.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(YMAudioQualityPreset.allCases) { preset in
                            let isSelected = audioEngine.qualitySettings.preset == preset
                            Button {
                                audioEngine.setAudioQualityPreset(preset)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(isSelected ? .accentColor : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(preset.title)
                                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                                .foregroundColor(.primary)

                                            if preset == .lossless {
                                                Text("HI-RES")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.orange.opacity(0.2))
                                                    .foregroundColor(.orange)
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                        }

                                        Text(preset.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(preset.shortBadge)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .padding(10)
                                .background(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Codec preference picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Предпочитаемый кодек")
                            .font(.subheadline.weight(.medium))

                        Picker("Кодек", selection: Binding(
                            get: { audioEngine.qualitySettings.codecPreference },
                            set: { audioEngine.setCodecPreference($0) }
                        )) {
                            ForEach(YMAudioCodecPreference.allCases) { codec in
                                Text(codec.title).tag(codec)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 480)
                    }
                    .padding(.top, 6)
                }

                Divider()

                // Section 2: Доступные потоки текущего трека
                if let currentTrack = audioEngine.currentTrack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Текущий трек и доступные потоки")
                            .font(.headline)

                        HStack(spacing: 12) {
                            CachedCoverImage(
                                coverUri: currentTrack.effectiveCoverUri,
                                size: .small,
                                displaySize: 40,
                                cornerRadius: 6
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentTrack.displayTitle)
                                    .font(.system(size: 13, weight: .medium))
                                Text(currentTrack.artistsString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let currentStream = audioEngine.currentStreamInfo {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Играет: \(currentStream.displayDescription)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    if let details = audioEngine.currentAudioFormatDetails {
                                        Text(details)
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if !audioEngine.availableStreamInfos.isEmpty {
                            Text("Выберите конкретный вариант потока:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 6) {
                                ForEach(audioEngine.availableStreamInfos) { stream in
                                    let isCurrent = audioEngine.currentStreamInfo?.matchesVariant(stream) == true
                                    Button {
                                        audioEngine.selectStreamVariant(stream)
                                    } label: {
                                        HStack {
                                            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isCurrent ? .accentColor : .secondary)

                                            Text(stream.displayDescription)
                                                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                                                .foregroundColor(.primary)

                                            Spacer()

                                            Text(stream.codec.uppercased())
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Divider()
                }

                // Section 3: Кэш и память
                VStack(alignment: .leading, spacing: 14) {
                    Text("Память и локальный кэш")
                        .font(.headline)

                    Text("Клиент оптимизирован для удержания расхода ОЗУ в пределах 45–65 МБ благодаря аппаратному даунсемплингу ImageIO, ограничению кэшей и разделению поисковых буферов.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Фоновая индексация всех треков Избранного (может увеличивать расход ОЗУ)", isOn: Binding(
                        get: { audioEngine.qualitySettings.preloadAllFavoritesInBackground },
                        set: { audioEngine.qualitySettings.setPreloadFavoritesInBackground($0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))

                    HStack(spacing: 12) {
                        Text("Лимит кэша обложек в памяти:")
                            .font(.system(size: 13))
                        Picker("", selection: Binding(
                            get: { audioEngine.qualitySettings.imageCacheLimitMB },
                            set: { audioEngine.qualitySettings.setImageCacheLimitMB($0) }
                        )) {
                            Text("10 МБ").tag(10)
                            Text("15 МБ (По умолчанию)").tag(15)
                            Text("20 МБ").tag(20)
                            Text("50 МБ").tag(50)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 190)
                    }

                    HStack(spacing: 14) {
                        Button("Сжать память (Выгрузить неиспользуемые данные)") {
                            audioEngine.qualitySettings.purgeUnusedMemory()
                            isMemoryCompressed = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Очистить кэш обложек и сети") {
                            Task {
                                await networkClient.clearCache()
                                await ImagePipeline.shared.clearCache()
                                isCacheCleared = true
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if isMemoryCompressed {
                        Text("Неиспользуемые данные и поисковый буфер выгружены из ОЗУ.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if isCacheCleared {
                        Text("Дисковый и сетевой кэш очищен.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 80)
        }
    }
}
