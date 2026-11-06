import SwiftUI

/// Elegant poster-style card for albums and singles with hover zoom, play overlay, and metadata.
public struct YMAlbumCard: View {
    public let album: YMAlbum
    public let onPlay: (() -> Void)?
    public let onSelect: (() -> Void)?

    @UIState private var isHovered = false

    public init(
        album: YMAlbum,
        onPlay: (() -> Void)? = nil,
        onSelect: (() -> Void)? = nil
    ) {
        self.album = album
        self.onPlay = onPlay
        self.onSelect = onSelect
    }

    public var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedCoverImage(
                        coverUri: album.coverUri,
                        size: .medium,
                        displaySize: 150,
                        cornerRadius: YMTheme.cornerRadiusMedium
                    )
                    .frame(width: 150, height: 150)
                    .ymCardHover(cornerRadius: YMTheme.cornerRadiusMedium, scale: 1.04)

                    // Play button overlay on hover
                    if isHovered, let onPlay = onPlay {
                        Button {
                            onPlay()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(YMTheme.accent))
                                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .onHover { isHovered = $0 }

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isHovered ? YMTheme.accent : YMTheme.fg)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let year = album.year {
                            Text(String(year))
                        }
                        if let genre = album.genre, !genre.isEmpty {
                            Text("· \(genre.capitalized)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(YMTheme.fg40)
                    .lineLimit(1)
                }
                .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Circular avatar card for artists with name and hover scale.
public struct YMArtistCard: View {
    public let artist: YMArtist
    public let onSelect: (() -> Void)?

    @UIState private var isHovered = false

    public init(artist: YMArtist, onSelect: (() -> Void)? = nil) {
        self.artist = artist
        self.onSelect = onSelect
    }

    public var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(spacing: 8) {
                CachedCoverImage(
                    coverUri: artist.coverUri,
                    size: .medium,
                    displaySize: 110,
                    cornerRadius: 55
                )
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(isHovered ? YMTheme.accent : YMTheme.border, lineWidth: isHovered ? 2 : 1)
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .shadow(color: .black.opacity(isHovered ? 0.35 : 0.1), radius: 10, y: 4)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isHovered)

                VStack(spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isHovered ? YMTheme.accent : YMTheme.fg)
                        .lineLimit(1)

                    Text("Исполнитель")
                        .font(.caption2)
                        .foregroundStyle(YMTheme.fg40)
                }
                .frame(width: 110)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
