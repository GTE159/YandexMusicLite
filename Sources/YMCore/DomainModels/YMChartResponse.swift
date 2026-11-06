import Foundation

/// Chart response returned by `GET /landing3/chart`.
public struct YMChartResponse: Codable, Sendable {
    public let chart: YMChartBlock?

    enum CodingKeys: String, CodingKey {
        case chart
    }

    public init(chart: YMChartBlock? = nil) {
        self.chart = chart
    }
}

public struct YMChartBlock: Codable, Sendable {
    public let id: String?
    public let title: String?
    public let description: String?
    public let tracks: [YMChartItem]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case tracks
    }

    public init(id: String? = nil, title: String? = nil, description: String? = nil, tracks: [YMChartItem] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.tracks = tracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .id)
        self.title = try? container.decodeIfPresent(String.self, forKey: .title)
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.tracks = (try? container.decodeIfPresent([YMChartItem].self, forKey: .tracks)) ?? []
    }
}

public struct YMChartItem: Codable, Sendable, Identifiable {
    public let id: String
    public let track: YMTrack?
    public let chart: YMChartPosition?

    enum CodingKeys: String, CodingKey {
        case id
        case track
        case chart
    }

    public init(id: String? = nil, track: YMTrack? = nil, chart: YMChartPosition? = nil) {
        self.id = id ?? track?.id ?? UUID().uuidString
        self.track = track
        self.chart = chart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = FlexibleIDDecoder.decodeStringIfPresent(from: container, forKey: .id)
        let decodedTrack = try? container.decodeIfPresent(YMTrack.self, forKey: .track)
        self.id = decodedId ?? decodedTrack?.id ?? UUID().uuidString
        self.track = decodedTrack
        self.chart = try? container.decodeIfPresent(YMChartPosition.self, forKey: .chart)
    }
}

public struct YMChartPosition: Codable, Sendable {
    public let position: Int
    public let progress: String?
    public let shift: Int?
    public let listeners: Int?

    enum CodingKeys: String, CodingKey {
        case position
        case progress
        case shift
        case listeners
    }

    public init(position: Int, progress: String? = nil, shift: Int? = nil, listeners: Int? = nil) {
        self.position = position
        self.progress = progress
        self.shift = shift
        self.listeners = listeners
    }

    public var progressSymbol: String {
        switch progress {
        case "up": return "▲"
        case "down": return "▼"
        case "new": return "NEW"
        default: return "—"
        }
    }
}
