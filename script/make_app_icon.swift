import AppKit
import Foundation

struct IconRenderer {
    let size = CGSize(width: 1024, height: 1024)

    func render(to outputURL: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw IconError.encodingFailed
        }

        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw IconError.encodingFailed
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        let context = graphicsContext.cgContext
        context.setFillColor(NSColor(calibratedRed: 0.956, green: 0.945, blue: 0.918, alpha: 1).cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        drawBase(in: context)
        drawBook(in: context)
        drawLetter()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw IconError.encodingFailed
        }

        try pngData.write(to: outputURL, options: .atomic)
    }

    private func drawBase(in context: CGContext) {
        let rect = CGRect(x: 104, y: 104, width: 816, height: 816)
        let shadowColor = NSColor(calibratedWhite: 0.20, alpha: 0.16).cgColor
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -20), blur: 34, color: shadowColor)
        let path = CGPath(roundedRect: rect, cornerWidth: 188, cornerHeight: 188, transform: nil)
        context.setFillColor(NSColor(calibratedRed: 0.956, green: 0.945, blue: 0.918, alpha: 1).cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        let stroke = CGPath(roundedRect: rect.insetBy(dx: 8, dy: 8), cornerWidth: 178, cornerHeight: 178, transform: nil)
        context.setStrokeColor(NSColor(calibratedRed: 0.78, green: 0.69, blue: 0.56, alpha: 0.32).cgColor)
        context.setLineWidth(8)
        context.addPath(stroke)
        context.strokePath()
    }

    private func drawBook(in context: CGContext) {
        let amber = NSColor(calibratedRed: 0.824, green: 0.553, blue: 0.204, alpha: 1).cgColor
        let ink = NSColor(calibratedRed: 0.188, green: 0.173, blue: 0.145, alpha: 1).cgColor
        let page = NSColor(calibratedRed: 0.996, green: 0.986, blue: 0.954, alpha: 1).cgColor

        context.saveGState()
        context.translateBy(x: 512, y: 512)
        context.rotate(by: -0.035)
        context.translateBy(x: -512, y: -512)

        let leftPage = CGRect(x: 236, y: 312, width: 268, height: 392)
        let rightPage = CGRect(x: 520, y: 312, width: 268, height: 392)

        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 18, color: NSColor.black.withAlphaComponent(0.12).cgColor)
        context.setFillColor(page)
        context.addPath(CGPath(roundedRect: leftPage, cornerWidth: 34, cornerHeight: 34, transform: nil))
        context.fillPath()
        context.addPath(CGPath(roundedRect: rightPage, cornerWidth: 34, cornerHeight: 34, transform: nil))
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)

        context.setFillColor(amber)
        context.fill(CGRect(x: 493, y: 314, width: 38, height: 388))

        context.setStrokeColor(ink.copy(alpha: 0.32)!)
        context.setLineWidth(10)
        context.setLineCap(.round)
        for y in stride(from: 616, through: 430, by: -54) {
            context.move(to: CGPoint(x: 286, y: CGFloat(y)))
            context.addLine(to: CGPoint(x: 448, y: CGFloat(y)))
            context.strokePath()
            context.move(to: CGPoint(x: 576, y: CGFloat(y)))
            context.addLine(to: CGPoint(x: 738, y: CGFloat(y)))
            context.strokePath()
        }

        context.setStrokeColor(amber.copy(alpha: 0.60)!)
        context.setLineWidth(12)
        context.move(to: CGPoint(x: 304, y: 354))
        context.addLine(to: CGPoint(x: 452, y: 354))
        context.strokePath()

        context.restoreGState()
    }

    private func drawLetter() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 188, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.188, green: 0.173, blue: 0.145, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let rect = CGRect(x: 0, y: 322, width: 1024, height: 230)
        NSString(string: "R").draw(in: rect, withAttributes: attributes)
    }
}

enum IconError: Error {
    case encodingFailed
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make_app_icon <output.png>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try IconRenderer().render(to: outputURL)
