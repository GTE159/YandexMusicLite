import Foundation

public struct YMTrack: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let version: String?
    public let durationMs: Int?
    public let available: Bool?
    public let artists: [YMArtist]
    public let albums: [YMAlbum]
    public let coverUri: String?
    public let realId: String?
    public let isPlaceholder: Bool
    public let isSpacer: Bool

    public init(
        id: String,
        title: String,
        version: String? = nil,
        durationMs: Int? = nil,
        available: Bool? = true,
        artists: [YMArtist] = [],
        albums: [YMAlbum] = [],
        coverUri: String? = nil,
        realId: String? = nil,
        isPlaceholder: Bool = false,
        isSpacer: Bool = false
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.durationMs = durationMs
        self.available = available
        self.artists = artists
        self.albums = albums
        self.coverUri = coverUri
        self.realId = realId
        self.isPlaceholder = isPlaceholder
        self.isSpacer = isSpacer
    }

    public static func placeholder(id: String) -> YMTrack {
        YMTrack(
            id: id,
            title: "",
            version: nil,
            durationMs: nil,
            available: true,
            artists: [],
            albums: [],
            coverUri: nil,
            realId: nil,
            isPlaceholder: true,
            isSpacer: false
        )
    }

    public static func bottomSpacer(id: String) -> YMTrack {
        YMTrack(
            id: id,
            title: "",
            version: nil,
            durationMs: nil,
            available: false,
            artists: [],
            albums: [],
            coverUri: nil,
            realId: nil,
            isPlaceholder: false,
            isSpacer: true
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case version
        case durationMs
        case available
        case artists
        case albums
        case coverUri
        case realId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Track ID can be Int or String in Yandex Music API responses
        if let idString = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .id) {
            self.id = idString
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Missing or invalid track ID (expected Int or String)"
            )
        }

        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Unknown Track"
        self.version = try? container.decodeIfPresent(String.self, forKey: .version)
        self.durationMs = try? container.decodeIfPresent(Int.self, forKey: .durationMs)
        self.available = try? container.decodeIfPresent(Bool.self, forKey: .available)
        self.artists = (try? container.decodeIfPresent([YMArtist].self, forKey: .artists)) ?? []
        // Memory Optimization: retain only the primary album (UI & Rotor only use albums.first)
        let rawAlbums = (try? container.decodeIfPresent([YMAlbum].self, forKey: .albums)) ?? []
        self.albums = rawAlbums.first.map { [$0] } ?? []
        self.coverUri = try? container.decodeIfPresent(String.self, forKey: .coverUri)
        self.realId = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .realId)
        self.isPlaceholder = false
        self.isSpacer = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(available, forKey: .available)
        try container.encode(artists, forKey: .artists)
        try container.encode(albums, forKey: .albums)
        try container.encodeIfPresent(coverUri, forKey: .coverUri)
        try container.encodeIfPresent(realId, forKey: .realId)
    }

    // MARK: - Computed Convenience Properties

    /// Effective cover URI fallback to first album if track-level coverUri is absent
    public var effectiveCoverUri: String? {
        coverUri ?? albums.first?.coverUri
    }

    /// Primary album ID if available
    public var primaryAlbumId: String? {
        albums.first?.id
    }

    /// Primary album title if available
    public var primaryAlbumTitle: String? {
        albums.first?.title
    }

    /// Formatted track ID with album ID required by Rotor telemetry API: "{trackId}:{albumId}"
    public var rotorTrackIdentifier: String {
        let albumId = primaryAlbumId ?? "0"
        return "\(id):\(albumId)"
    }

    /// Comma-separated artists list
    public var artistsString: String {
        if artists.isEmpty {
            return "Unknown Artist"
        }
        return artists.map(\.name).joined(separator: ", ")
    }

    /// Full display title including version (e.g. "Song (Remix)")
    public var displayTitle: String {
        if let version = version, !version.isEmpty {
            return "\(title) (\(version))"
        }
        return title
    }

    /// Formatted duration (e.g. "3:45")
    public var formattedDuration: String {
        guard let ms = durationMs, ms > 0 else { return "--:--" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public func coverURL(size: YMCoverSize = .medium) -> URL? {
        YMCoverURLBuilder.buildURL(from: effectiveCoverUri, size: size)
    }
}
