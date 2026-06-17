import AppKit
import Foundation

struct DMGBackgroundRenderer {
    let logicalSize = CGSize(width: 660, height: 400)

    func render(to outputURL: URL, scale: CGFloat) throws {
        let pixelSize = CGSize(width: logicalSize.width * scale, height: logicalSize.height * scale)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw RenderError.encodingFailed
        }

        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw RenderError.encodingFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        let context = graphicsContext.cgContext
        context.scaleBy(x: scale, y: scale)

        drawPaper(in: context)
        drawInstallTargets(in: context)
        drawArrow(in: context)
        drawText()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.encodingFailed
        }
        try pngData.write(to: outputURL, options: .atomic)
    }

    private func drawPaper(in context: CGContext) {
        let background = NSColor(calibratedRed: 0.956, green: 0.945, blue: 0.918, alpha: 1).cgColor
        let border = NSColor(calibratedRed: 0.49, green: 0.40, blue: 0.28, alpha: 0.16).cgColor
        let fiber = NSColor(calibratedRed: 0.54, green: 0.47, blue: 0.37, alpha: 0.08).cgColor

        context.setFillColor(background)
        context.fill(CGRect(origin: .zero, size: logicalSize))

        context.setStrokeColor(fiber)
        context.setLineWidth(1)
        for y in stride(from: 38, through: 360, by: 31) {
            context.move(to: CGPoint(x: 36, y: CGFloat(y)))
            context.addLine(to: CGPoint(x: 624, y: CGFloat(y) + 4))
            context.strokePath()
        }

        let frame = CGRect(x: 18, y: 18, width: 624, height: 364)
        context.setStrokeColor(border)
        context.setLineWidth(2)
        context.addPath(CGPath(roundedRect: frame, cornerWidth: 28, cornerHeight: 28, transform: nil))
        context.strokePath()
    }

    private func drawInstallTargets(in context: CGContext) {
        let fill = NSColor(calibratedWhite: 1, alpha: 0.36).cgColor
        let stroke = NSColor(calibratedRed: 0.824, green: 0.553, blue: 0.204, alpha: 0.34).cgColor
        let shadow = NSColor(calibratedWhite: 0.16, alpha: 0.10).cgColor

        for rect in [
            CGRect(x: 90, y: 128, width: 150, height: 150),
            CGRect(x: 420, y: 128, width: 150, height: 150)
        ] {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -7), blur: 18, color: shadow)
            context.setFillColor(fill)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 32, cornerHeight: 32, transform: nil))
            context.fillPath()
            context.restoreGState()

            context.saveGState()
            context.setStrokeColor(stroke)
            context.setLineWidth(2)
            context.setLineDash(phase: 0, lengths: [8, 7])
            context.addPath(CGPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerWidth: 31, cornerHeight: 31, transform: nil))
            context.strokePath()
            context.restoreGState()
        }
    }

    private func drawArrow(in context: CGContext) {
        let amber = NSColor(calibratedRed: 0.824, green: 0.553, blue: 0.204, alpha: 1).cgColor
        let mutedAmber = NSColor(calibratedRed: 0.824, green: 0.553, blue: 0.204, alpha: 0.20).cgColor

        context.saveGState()
        context.setStrokeColor(mutedAmber)
        context.setLineWidth(18)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 272, y: 203))
        context.addLine(to: CGPoint(x: 388, y: 203))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(amber)
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.setLineDash(phase: 0, lengths: [10, 8])
        context.move(to: CGPoint(x: 272, y: 203))
        context.addLine(to: CGPoint(x: 386, y: 203))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setFillColor(amber)
        let arrowHead = CGMutablePath()
        arrowHead.move(to: CGPoint(x: 404, y: 203))
        arrowHead.addLine(to: CGPoint(x: 377, y: 220))
        arrowHead.addLine(to: CGPoint(x: 383, y: 203))
        arrowHead.addLine(to: CGPoint(x: 377, y: 186))
        arrowHead.closeSubpath()
        context.addPath(arrowHead)
        context.fillPath()
        context.restoreGState()
    }

    private func drawText() {
        drawString(
            "将 Reader 拖入 Applications 安装",
            in: CGRect(x: 0, y: 323, width: logicalSize.width, height: 38),
            size: 24,
            weight: .semibold,
            color: NSColor(calibratedRed: 0.188, green: 0.173, blue: 0.145, alpha: 1)
        )

        drawString(
            "拖入安装",
            in: CGRect(x: 262, y: 226, width: 136, height: 28),
            size: 16,
            weight: .medium,
            color: NSColor(calibratedRed: 0.44, green: 0.32, blue: 0.18, alpha: 1)
        )

        drawString(
            "打开后拖拽一次即可完成安装",
            in: CGRect(x: 0, y: 42, width: logicalSize.width, height: 24),
            size: 14,
            weight: .regular,
            color: NSColor(calibratedRed: 0.36, green: 0.32, blue: 0.27, alpha: 0.82)
        )
    }

    private func drawString(
        _ string: String,
        in rect: CGRect,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: string).draw(in: rect, withAttributes: attributes)
    }
}

enum RenderError: Error {
    case encodingFailed
}

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: make_dmg_background <output.png> <output@2x.png> <scale>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let retinaOutputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let retinaScale = Double(CommandLine.arguments[3]), retinaScale > 1 else {
    FileHandle.standardError.write(Data("error: scale must be greater than 1\n".utf8))
    exit(2)
}

let renderer = DMGBackgroundRenderer()
try renderer.render(to: outputURL, scale: 1)
try renderer.render(to: retinaOutputURL, scale: CGFloat(retinaScale))
