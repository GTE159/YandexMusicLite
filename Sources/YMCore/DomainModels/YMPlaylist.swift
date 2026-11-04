import Foundation

public struct YMTrackShort: Codable, Sendable, Identifiable {
    public let id: String
    public let albumId: String?
    public let timestamp: String?
    public let track: YMTrack?

    enum CodingKeys: String, CodingKey {
        case id
        case albumId
        case timestamp
        case track
    }

    public init(id: String, albumId: String? = nil, timestamp: String? = nil, track: YMTrack? = nil) {
        self.id = id
        self.albumId = albumId
        self.timestamp = timestamp
        self.track = track
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .id) {
            self.id = idString
        } else if let nestedTrack = try? container.decodeIfPresent(YMTrack.self, forKey: .track) {
            self.id = nestedTrack.id
        } else {
            self.id = UUID().uuidString
        }

        self.albumId = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .albumId)
        self.timestamp = try? container.decodeIfPresent(String.self, forKey: .timestamp)
        self.track = try? container.decodeIfPresent(YMTrack.self, forKey: .track)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(albumId, forKey: .albumId)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(track, forKey: .track)
    }
}

public struct YMPlaylist: Codable, Sendable, Identifiable {
    public var id: String { "\(uid)_\(kind)" }
    public let uid: String
    public let kind: Int
    public let title: String
    public let trackCount: Int?
    public let coverUri: String?
    public let ogImage: String?
    public let tracks: [YMTrackShort]?

    enum CodingKeys: String, CodingKey {
        case uid
        case kind
        case title
        case trackCount
        case cover
        case coverUri
        case ogImage
        case tracks
        case owner
    }

    enum CoverKeys: String, CodingKey {
        case uri
        case dir
        case itemsUri
    }

    enum OwnerKeys: String, CodingKey {
        case uid
    }

    public init(
        uid: String,
        kind: Int,
        title: String,
        trackCount: Int? = nil,
        coverUri: String? = nil,
        ogImage: String? = nil,
        tracks: [YMTrackShort]? = nil
    ) {
        self.uid = uid
        self.kind = kind
        self.title = title
        self.trackCount = trackCount
        self.coverUri = coverUri
        self.ogImage = ogImage
        self.tracks = tracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let directUid = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .uid) {
            self.uid = directUid
        } else if let ownerContainer = try? container.nestedContainer(keyedBy: OwnerKeys.self, forKey: .owner),
                  let ownerUid = FlexibleIDDecoder.decodeStringIfPresent(from: ownerContainer, forKey: .uid) {
            self.uid = ownerUid
        } else {
            self.uid = "0"
        }

        self.kind = (try? container.decodeIfPresent(Int.self, forKey: .kind)) ?? 0
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Плейлист"
        self.trackCount = try? container.decodeIfPresent(Int.self, forKey: .trackCount)
        self.ogImage = try? container.decodeIfPresent(String.self, forKey: .ogImage)

        // Cover resolution with fallback to itemsUri.first and ogImage
        var resolvedCover: String? = nil
        if let coverContainer = try? container.nestedContainer(keyedBy: CoverKeys.self, forKey: .cover) {
            resolvedCover = (try? coverContainer.decodeIfPresent(String.self, forKey: .uri))
                ?? (try? coverContainer.decodeIfPresent(String.self, forKey: .dir))
                ?? (try? coverContainer.decodeIfPresent([String].self, forKey: .itemsUri))?.first
        }

        if resolvedCover == nil {
            resolvedCover = (try? container.decodeIfPresent(String.self, forKey: .coverUri))
                ?? (try? container.decodeIfPresent(String.self, forKey: .ogImage))
        }

        self.coverUri = resolvedCover
        self.tracks = try? container.decodeIfPresent([YMTrackShort].self, forKey: .tracks)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(trackCount, forKey: .trackCount)
        try container.encodeIfPresent(coverUri, forKey: .coverUri)
        try container.encodeIfPresent(ogImage, forKey: .ogImage)
        try container.encodeIfPresent(tracks, forKey: .tracks)
    }

    public func coverURL(size: YMCoverSize = .medium) -> URL? {
        YMCoverURLBuilder.buildURL(from: coverUri, size: size)
    }
}
