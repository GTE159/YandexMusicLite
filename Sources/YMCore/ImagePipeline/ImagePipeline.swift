import Foundation
import AppKit

/// Actor-based image cache pipeline with configurable RAM cost limit (default 15 MB)
/// and hardware-accelerated downsampling via ImageIO.
public actor ImagePipeline {
    public static let shared = ImagePipeline()

    private let memoryCache: NSCache<NSString, NSImage>
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]

    public init(maxMemoryCost: Int = 15 * 1024 * 1024) {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = maxMemoryCost
        cache.countLimit = 250 // Жесткий потолок количества обложек в ОЗУ
        self.memoryCache = cache
    }

    /// Dynamically adjusts the memory cache cost limit in megabytes
    public func setMaxMemoryCost(mb: Int) {
        memoryCache.totalCostLimit = max(5, mb) * 1024 * 1024
    }

    /// Fetches image from cache or downloads and downsamples asynchronously
    public func image(for coverUri: String?, size: YMCoverSize = .medium) async -> NSImage? {
        guard let coverUri = coverUri, !coverUri.isEmpty else { return nil }

        let cacheKey = "\(coverUri)_\(size.rawValue)" as NSString
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        if let existingTask = inFlightTasks[cacheKey as String] {
            return await existingTask.value
        }

        guard let url = YMCoverURLBuilder.buildURL(from: coverUri, size: size) else {
            return nil
        }

        let maxPixelSize: CGFloat
        switch size {
        case .small: maxPixelSize = 100
        case .medium: maxPixelSize = 200
        case .artwork: maxPixelSize = 300
        case .large: maxPixelSize = 400
        }

        let task = Task<NSImage?, Never> {
            guard let (image, byteCost) = await ImageDownsampler.fetchAndDownsampleWithCost(from: url, maxPixelSize: maxPixelSize),
                  !Task.isCancelled else {
                return nil
            }
            self.memoryCache.setObject(image, forKey: cacheKey, cost: byteCost)
            return image
        }

        inFlightTasks[cacheKey as String] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: cacheKey as String)
        return result
    }

    public func clearCache() {
        memoryCache.removeAllObjects()
    }

    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
}
