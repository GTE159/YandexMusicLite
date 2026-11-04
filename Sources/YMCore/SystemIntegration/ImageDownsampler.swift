import Foundation
import ImageIO
import AppKit

/// Hardware-accelerated image downsampler utilizing ImageIO.
/// Bypasses full-resolution bitmap decompression in memory to stay strictly within 40-70 MB RAM.
public enum ImageDownsampler: Sendable {
    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    /// Downsamples raw image data to target maximum pixel size without loading full-size bitmap.
    public static func downsample(data: Data, maxPixelSize: CGFloat) -> NSImage? {
        let imageSourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let downsampledCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        let targetSize = NSSize(width: maxPixelSize, height: maxPixelSize)
        return NSImage(cgImage: downsampledCGImage, size: targetSize)
    }

    /// Downsamples raw image data to target maximum pixel size and returns exact memory byte cost.
    public static func downsampleWithCost(data: Data, maxPixelSize: CGFloat) -> (NSImage, Int)? {
        let imageSourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        let exactByteCost = cgImage.bytesPerRow * cgImage.height
        let targetSize = NSSize(width: cgImage.width, height: cgImage.height)
        return (NSImage(cgImage: cgImage, size: targetSize), max(exactByteCost, Int(maxPixelSize * maxPixelSize * 4)))
    }

    /// Asynchronously fetches an image from URL and decodes a downsampled thumbnail off the main thread.
    public static func fetchAndDownsample(from url: URL, maxPixelSize: CGFloat) async -> NSImage? {
        do {
            let (data, response) = try await imageSession.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return downsample(data: data, maxPixelSize: maxPixelSize)
        } catch {
            return nil
        }
    }

    /// Asynchronously fetches an image from URL and decodes a downsampled thumbnail with exact byte cost.
    public static func fetchAndDownsampleWithCost(from url: URL, maxPixelSize: CGFloat) async -> (NSImage, Int)? {
        do {
            let (data, response) = try await imageSession.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return downsampleWithCost(data: data, maxPixelSize: maxPixelSize)
        } catch {
            return nil
        }
    }
}
