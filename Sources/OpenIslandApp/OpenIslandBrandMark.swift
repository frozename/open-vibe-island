import AppKit
import SwiftUI

struct OpenIslandBrandMark: View {
    enum Style {
        case duotone
        case template
    }

    let size: CGFloat
    var tint: Color = .mint
    var isAnimating: Bool = false
    var style: Style = .duotone

    private static let scoutPattern = [
        "..B..B..",
        "..BBBB..",
        ".BHHHHB.",
        "BBHEHEBB",
        ".BHHHHB.",
        "..BBBB..",
        ".B....B.",
        "........",
    ]

    private static let pixels: [(x: Int, y: Int, role: Character)] = scoutPattern.enumerated().flatMap { rowIndex, row in
        row.enumerated().compactMap { columnIndex, character in
            character == "." ? nil : (columnIndex, rowIndex, character)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / 8, proxy.size.height / 8)
            let markWidth = cell * 8
            let markHeight = cell * 8
            let originX = (proxy.size.width - markWidth) / 2
            let originY = (proxy.size.height - markHeight) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(Self.pixels.enumerated()), id: \.offset) { _, pixel in
                    Rectangle()
                        .fill(fillColor(for: pixel.role))
                        .frame(width: cell, height: cell)
                        .offset(
                            x: originX + CGFloat(pixel.x) * cell,
                            y: originY + CGFloat(pixel.y) * cell
                        )
                }
            }
        }
        .frame(width: size, height: size)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
    }

    /// Creates an `NSImage` suitable for use as a macOS menu bar icon.
    /// Marked as a template image so the system handles light/dark/active appearance.
    private static let _menuBarIcon: NSImage = {
        let pointSize: CGFloat = 18
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { bounds in
            let cellSize = bounds.width / 8
            for pixel in pixels {
                let alpha: CGFloat = pixel.role == "E" ? 0.9 : 1.0
                NSColor.black.withAlphaComponent(alpha).setFill()
                NSRect(
                    x: CGFloat(pixel.x) * cellSize,
                    y: CGFloat(pixel.y) * cellSize,
                    width: cellSize,
                    height: cellSize
                ).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()

    static func menuBarIcon() -> NSImage { _menuBarIcon }

    private func fillColor(for role: Character) -> Color {
        switch style {
        case .duotone:
            switch role {
            case "B":
                return tint.opacity(isAnimating ? 1.0 : 0.86)
            case "H":
                return tint.opacity(isAnimating ? 0.84 : 0.64)
            case "E":
                return Color.black.opacity(0.72)
            default:
                return .clear
            }
        case .template:
            return Color.primary.opacity(role == "E" ? 0.9 : 1.0)
        }
    }
}
