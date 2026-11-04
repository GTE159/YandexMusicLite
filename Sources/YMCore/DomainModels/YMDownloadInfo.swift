import Foundation

// MARK: - Quality & Codec Enums

public enum YMAudioQualityPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto = "auto"
    case lossless = "lossless"
    case high320 = "320"
    case medium192 = "192"
    case standard128 = "128"
    case low64 = "64"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return "Авто (Лучшее доступное)"
        case .lossless: return "Lossless (FLAC)"
        case .high320: return "Высокое (320 kbps)"
        case .medium192: return "Оптимальное (192 kbps)"
        case .standard128: return "Стандартное (128 kbps)"
        case .low64: return "Экономичное (64 kbps)"
        }
    }

    public var shortBadge: String {
        switch self {
        case .auto: return "AUTO"
        case .lossless: return "LOSSLESS"
        case .high320: return "320K"
        case .medium192: return "192K"
        case .standard128: return "128K"
        case .low64: return "64K"
        }
    }

    public var subtitle: String {
        switch self {
        case .auto: return "Автоматический выбор максимального качества"
        case .lossless: return "Качество без потерь (до 1411 kbps), если поддерживается"
        case .high320: return "Максимальное сжатие MP3/AAC для чистого звука"
        case .medium192: return "Оптимальный баланс качества и трафика"
        case .standard128: return "Базовый битрейт для умеренного потребления данных"
        case .low64: return "Минимальное потребление ОЗУ и интернет-трафика"
        }
    }

    public var targetBitrate: Int? {
        switch self {
        case .auto: return nil
        case .lossless: return 1411
        case .high320: return 320
        case .medium192: return 192
        case .standard128: return 128
        case .low64: return 64
        }
    }

    /// Parameter mapping for GET /get-file-info
    public var fileInfoQualityParam: String {
        switch self {
        case .lossless, .auto:
            return "lossless"
        case .high320:
            return "hq"
        case .medium192, .standard128:
            return "nq"
        case .low64:
            return "lq"
        }
    }
}

public enum YMAudioCodecPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case any = "any"
    case mp3 = "mp3"
    case aac = "aac"
    case heAac = "he-aac"
    case flac = "flac"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .any: return "Любой (Авто)"
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .heAac: return "HE-AAC / AAC-MP4"
        case .flac: return "FLAC"
        }
    }
}

// MARK: - Download Info Model

public struct YMDownloadInfo: Codable, Sendable, Hashable, Identifiable {
    /// Стабильный идентификатор варианта потока по кодеку и битрейту (не зависит от временного URL)
    public var variantKey: String {
        "\(codec.lowercased())_\(bitrateInKbps)_\(isDirectCdnStream ? "cdn" : "storage")"
    }

    public var id: String { variantKey }

    public let codec: String
    public let bitrateInKbps: Int
    public let gain: Bool?
    public let preview: Bool?
    public let downloadInfoUrl: URL
    public let direct: Bool?
    public let lossless: Bool?

    public init(
        codec: String,
        bitrateInKbps: Int,
        gain: Bool? = nil,
        preview: Bool? = nil,
        downloadInfoUrl: URL,
        direct: Bool? = nil,
        lossless: Bool? = nil
    ) {
        self.codec = codec
        self.bitrateInKbps = bitrateInKbps
        self.gain = gain
        self.preview = preview
        self.downloadInfoUrl = downloadInfoUrl
        self.direct = direct
        self.lossless = lossless
    }

    enum CodingKeys: String, CodingKey {
        case codec
        case bitrateInKbps
        case gain
        case preview
        case downloadInfoUrl
        case direct
        case lossless
    }

    public var isLossless: Bool {
        lossless == true || codec.lowercased().contains("flac") || codec.lowercased().contains("alac") || bitrateInKbps > 500
    }

    public var isDirectCdnStream: Bool {
        if direct == true { return true }
        if direct == false { return false }
        let str = downloadInfoUrl.absoluteString.lowercased()
        if str.contains("download-info") || str.contains("u2fsdgvk") || str.contains("api.music.yandex.net/get-mp3/") {
            return false
        }
        return str.contains(".strm.yandex.net") ||
               str.contains("/music-v2/raw/") ||
               str.contains(".mp3") ||
               str.contains(".flac") ||
               str.contains(".m4a") ||
               str.contains("/get-file/")
    }

    public var displayCodec: String {
        switch codec.lowercased() {
        case "flac-mp4": return "FLAC (MP4)"
        case "flac": return "FLAC"
        case "aac-mp4": return "AAC (MP4)"
        case "he-aac", "he-aac-mp4": return "HE-AAC"
        default: return codec.uppercased()
        }
    }

    public var displayDescription: String {
        if isLossless {
            return "Lossless (\(displayCodec), ~\(bitrateInKbps) kbps)"
        }
        return "\(bitrateInKbps) kbps \(displayCodec)"
    }

    /// Проверяет, соответствует ли поток тому же качеству и кодеку
    public func matchesVariant(_ other: YMDownloadInfo) -> Bool {
        self.codec.lowercased() == other.codec.lowercased() &&
        self.bitrateInKbps == other.bitrateInKbps &&
        self.isLossless == other.isLossless
    }
}

// MARK: - Audio Stream Selection

public extension Collection where Element == YMDownloadInfo {
    /// Selects the best download info element according to legacy / default specification:
    /// 1. Filters non-preview tracks (if any available).
    /// 2. Prefers codec containing "mp3" or "aac".
    /// 3. Chooses the maximum bitrate (up to 320 kbps).
    func selectBestAudioDownloadInfo() -> YMDownloadInfo? {
        let nonPreview = self.filter { !($0.preview ?? false) }
        let candidates = nonPreview.isEmpty ? Array(self) : nonPreview

        return candidates
            .filter { candidate in
                let c = candidate.codec.lowercased()
                return c.contains("mp3") || c.contains("aac") || c.contains("flac")
            }
            .max { a, b in
                if a.bitrateInKbps != b.bitrateInKbps {
                    return a.bitrateInKbps < b.bitrateInKbps
                }
                // If bitrates are equal, prefer mp3 over aac
                return !a.codec.lowercased().contains("mp3") && b.codec.lowercased().contains("mp3")
            } ?? candidates.max(by: { $0.bitrateInKbps < $1.bitrateInKbps })
    }

    /// Selects download info matching the requested quality preset and codec preference.
    /// Handles fallback gracefully if the exact bitrate or codec is unavailable.
    func selectDownloadInfo(
        preset: YMAudioQualityPreset,
        codecPreference: YMAudioCodecPreference = .any
    ) -> YMDownloadInfo? {
        let nonPreview = self.filter { !($0.preview ?? false) }
        let pool = nonPreview.isEmpty ? Array(self) : nonPreview
        guard !pool.isEmpty else { return nil }

        // 1. Сначала пробуем отфильтровать по предпочитаемому кодеку
        let codecFiltered: [YMDownloadInfo]
        switch codecPreference {
        case .mp3:
            codecFiltered = pool.filter { $0.codec.lowercased().contains("mp3") }
        case .aac:
            codecFiltered = pool.filter { $0.codec.lowercased().contains("aac") && !$0.codec.lowercased().contains("he-aac") }
        case .heAac:
            codecFiltered = pool.filter { $0.codec.lowercased().contains("he-aac") || $0.codec.lowercased().contains("aac-mp4") }
        case .flac:
            codecFiltered = pool.filter { $0.isLossless }
        case .any:
            codecFiltered = pool
        }

        // Если пользователь явно выбрал пресет (например 64k или Lossless), но в рамках выбранного кодека
        // нет подходящего битрейта, а в общем пуле он есть — учитываем приоритет пресета при codecPreference == .any,
        // а при явно заданном кодеке выбираем лучшее совпадение внутри кодека (или fallback на общий пул).
        let candidates = codecFiltered.isEmpty ? pool : codecFiltered

        switch preset {
        case .auto:
            return candidates.max { a, b in
                if a.isLossless != b.isLossless {
                    return !a.isLossless && b.isLossless
                }
                if a.bitrateInKbps != b.bitrateInKbps {
                    return a.bitrateInKbps < b.bitrateInKbps
                }
                return !a.codec.lowercased().contains("mp3") && b.codec.lowercased().contains("mp3")
            }

        case .lossless:
            // Ищем Lossless сначала в кандидатах, затем во всём пуле
            if let flac = candidates.first(where: { $0.isLossless }) ?? pool.first(where: { $0.isLossless }) {
                return flac
            }
            return candidates.filter { !$0.isLossless }.max(by: { $0.bitrateInKbps < $1.bitrateInKbps })
                ?? pool.max(by: { $0.bitrateInKbps < $1.bitrateInKbps })

        case .high320, .medium192, .standard128, .low64:
            guard let target = preset.targetBitrate else { return nil }
            let nonLosslessCandidates = candidates.filter { !$0.isLossless }
            let searchPool = nonLosslessCandidates.isEmpty ? pool.filter { !$0.isLossless } : nonLosslessCandidates
            let effectivePool = searchPool.isEmpty ? candidates : searchPool

            // 1. Точное совпадение битрейта в рамках кодека
            if let exact = effectivePool.first(where: { $0.bitrateInKbps == target }) {
                return exact
            }
            // 2. Если кодек .any или в текущем кодеке нет точного битрейта, проверим точное совпадение во всём пуле
            if codecPreference == .any, let exactInAll = pool.filter({ !$0.isLossless }).first(where: { $0.bitrateInKbps == target }) {
                return exactInAll
            }
            // 3. Ближайший по битрейту (минимальная разница abs(bitrate - target))
            return effectivePool.min { a, b in
                let diffA = abs(a.bitrateInKbps - target)
                let diffB = abs(b.bitrateInKbps - target)
                if diffA != diffB {
                    return diffA < diffB
                }
                return a.bitrateInKbps > b.bitrateInKbps
            }
        }
    }
}
