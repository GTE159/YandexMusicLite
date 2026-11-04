import Foundation

public struct YMStreamData: Codable, Sendable, Hashable {
    public let host: String
    public let path: String
    public let ts: String
    public let s: String
    public let region: Int?

    public init(
        host: String,
        path: String,
        ts: String,
        s: String,
        region: Int? = nil
    ) {
        self.host = host
        self.path = path
        self.ts = ts
        self.s = s
        self.region = region
    }

    enum CodingKeys: String, CodingKey {
        case host
        case path
        case ts
        case s
        case region
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.host = try container.decode(String.self, forKey: .host)
        self.path = try container.decode(String.self, forKey: .path)

        // ts can come as String or Int/Long in various API responses
        if let tsString = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .ts) {
            self.ts = tsString
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .ts,
                in: container,
                debugDescription: "Missing or invalid timestamp string/int"
            )
        }

        self.s = try container.decode(String.self, forKey: .s)
        self.region = try? container.decodeIfPresent(Int.self, forKey: .region)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(host, forKey: .host)
        try container.encode(path, forKey: .path)
        try container.encode(ts, forKey: .ts)
        try container.encode(s, forKey: .s)
        try container.encodeIfPresent(region, forKey: .region)
    }
}
