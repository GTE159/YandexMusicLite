import Foundation

public struct YMAlbum: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let year: Int?
    public let releaseDate: String?
    public let coverUri: String?
    public let genre: String?
    public let trackCount: Int?
    public let artists: [YMArtist]?

    public init(
        id: String,
        title: String,
        year: Int? = nil,
        releaseDate: String? = nil,
        coverUri: String? = nil,
        genre: String? = nil,
        trackCount: Int? = nil,
        artists: [YMArtist]? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.releaseDate = releaseDate
        self.coverUri = coverUri
        self.genre = genre
        self.trackCount = trackCount
        self.artists = artists
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case year
        case releaseDate
        case coverUri
        case genre
        case trackCount
        case artists
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let idString = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .id) {
            self.id = idString
        } else {
            self.id = UUID().uuidString
        }

        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Unknown Album"
        self.year = try? container.decodeIfPresent(Int.self, forKey: .year)
        self.releaseDate = try? container.decodeIfPresent(String.self, forKey: .releaseDate)
        self.coverUri = try? container.decodeIfPresent(String.self, forKey: .coverUri)
        self.genre = try? container.decodeIfPresent(String.self, forKey: .genre)
        self.trackCount = try? container.decodeIfPresent(Int.self, forKey: .trackCount)
        // Memory Optimization: Do not decode nested artists inside album (saves thousands of duplicate structs).
        // Artists are already preserved in parent YMTrack.
        self.artists = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(coverUri, forKey: .coverUri)
        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(trackCount, forKey: .trackCount)
        try container.encodeIfPresent(artists, forKey: .artists)
    }

    public func coverURL(size: YMCoverSize = .medium) -> URL? {
        YMCoverURLBuilder.buildURL(from: coverUri, size: size)
    }
}
