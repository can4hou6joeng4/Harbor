import AppKit
import ReaderCore
import SwiftUI

struct CoverGradient: View {
    let hue: Double
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: normalizedHue, saturation: 0.28, brightness: 0.95),
                        Color(hue: shiftedHue, saturation: 0.42, brightness: 0.74)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.48),
                        Color.white.opacity(0.0)
                    ],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 180
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.black.opacity(0.10), lineWidth: 0.5)
            }
    }

    private var normalizedHue: Double {
        (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
    }

    private var shiftedHue: Double {
        ((hue + 32).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
    }
}

struct CoverArtwork: View {
    let coverPath: String?
    let hue: Double
    var cornerRadius: CGFloat = 10
    var contentMode: ContentMode = .fill

    var body: some View {
        if let image = coverPath.flatMap(Self.image(for:)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.black.opacity(0.10), lineWidth: 0.5)
                }
        } else {
            CoverGradient(hue: hue, cornerRadius: cornerRadius)
        }
    }

    private static func image(for relativePath: String) -> NSImage? {
        guard let root = try? LocalCaptureAssetStore.defaultRootDirectory() else {
            return nil
        }
        return NSImage(contentsOf: root.appendingPathComponent(relativePath))
    }
}
