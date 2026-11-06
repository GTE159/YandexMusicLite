import Foundation

/// Track supplement containing lyrics, returned by `GET /tracks/{trackId}/supplement`.
public struct YMTrackSupplement: Codable, Sendable {
    public let id: String
    public let lyrics: YMLyrics?

    enum CodingKeys: String, CodingKey {
        case id
        case lyrics
    }

    public init(id: String, lyrics: YMLyrics? = nil) {
        self.id = id
        self.lyrics = lyrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .id) {
            self.id = idString
        } else {
            self.id = UUID().uuidString
        }
        self.lyrics = try? container.decodeIfPresent(YMLyrics.self, forKey: .lyrics)
    }
}

public struct YMLyrics: Codable, Sendable {
    public let id: Int?
    public let lyrics: String?
    public let fullLyrics: String?
    public let hasRights: Bool?
    public let textLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case lyrics
        case fullLyrics
        case hasRights
        case textLanguage
    }

    public init(
        id: Int? = nil,
        lyrics: String? = nil,
        fullLyrics: String? = nil,
        hasRights: Bool? = nil,
        textLanguage: String? = nil
    ) {
        self.id = id
        self.lyrics = lyrics
        self.fullLyrics = fullLyrics
        self.hasRights = hasRights
        self.textLanguage = textLanguage
    }

    /// Best available lyrics text
    public var displayText: String {
        if let full = fullLyrics, !full.isEmpty {
            return full
        }
        return lyrics ?? "Текст песни отсутствует."
    }
}
