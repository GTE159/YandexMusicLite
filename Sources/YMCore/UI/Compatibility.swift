import SwiftUI
#if canImport(Observation)
import Observation
#endif

/// Cross-version compatibility layer for macOS 14.0+ (Sonoma, Sequoia and newer).
/// The application target strictly requires macOS 14.0+ due to native Observation and Swift 6 concurrency.
/// Provides safety wrappers, SwiftUI view extensions, and OS version detection.
public enum macOSCompatibility {
    public static var currentOSVersion: OperatingSystemVersion {
        ProcessInfo.processInfo.operatingSystemVersion
    }

    public static var osVersionString: String {
        let v = currentOSVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    public static var isAtLeastMonterey: Bool {
        if #available(macOS 12.0, *) { return true }
        return false
    }

    public static var isAtLeastVentura: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    public static var isAtLeastSonoma: Bool {
        if #available(macOS 14.0, *) { return true }
        return false
    }

    public static var isAtLeastSequoia: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }

    public static var osMarketingName: String {
        let major = currentOSVersion.majorVersion
        switch major {
        case 11: return "macOS Big Sur"
        case 12: return "macOS Monterey"
        case 13: return "macOS Ventura"
        case 14: return "macOS Sonoma"
        case 15: return "macOS Sequoia"
        case 16...27: return "macOS \(major)"
        default: return "macOS \(major)"
        }
    }
}

// MARK: - SwiftUI View Extensions for Cross-Version macOS Compatibility

public extension View {
    /// Safe scroll content background configuration for macOS 12 through macOS 27+
    @ViewBuilder
    func compatibleScrollContentBackground(hidden: Bool = true) -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(hidden ? .hidden : .visible)
        } else {
            self
        }
    }

    /// Safe monospaced digit formatting across macOS versions
    @ViewBuilder
    func compatibleMonospacedDigit() -> some View {
        if #available(macOS 12.0, *) {
            self.monospacedDigit()
        } else {
            self
        }
    }

    /// Safe material background across versions
    @ViewBuilder
    func compatibleMaterialBackground() -> some View {
        if #available(macOS 12.0, *) {
            self.background(.ultraThinMaterial)
        } else {
            self.background(Color(NSColor.windowBackgroundColor))
        }
    }
}
