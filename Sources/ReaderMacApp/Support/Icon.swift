import ReaderCore
import SwiftUI

struct Icon: View {
    let name: String
    var size: CGFloat = 16
    var weight: Font.Weight = .medium

    var body: some View {
        Group {
            if VectorIcon.supports(name) {
                VectorIcon(name: name)
            } else {
                Image(systemName: symbolName(for: name))
                    .font(.system(size: size, weight: weight))
            }
        }
        .frame(width: size + 2, height: size + 2)
    }

    private func symbolName(for name: String) -> String {
        switch name {
        case "archive": "archivebox"
        case "bookmark": "bookmark"
        case "calendar": "calendar"
        case "chat": "bubble.left.and.bubble.right"
        case "check": "checkmark"
        case "check-circle": "checkmark.circle.fill"
        case "chev": "chevron.right"
        case "clock": "clock"
        case "close": "xmark"
        case "copy": "doc.on.doc"
        case "doc": "doc.text"
        case "dot": "circle.fill"
        case "ellipsis": "ellipsis"
        case "eye": "eye"
        case "folder": "folder"
        case "gear": "gearshape"
        case "globe": "globe"
        case "highlighter": "highlighter"
        case "inbox": "tray"
        case "link": "link"
        case "list": "list.bullet"
        case "markdown": "curlybraces"
        case "minus": "minus"
        case "moon": "moon"
        case "panel-right": "sidebar.right"
        case "paperclip": "paperclip"
        case "pencil": "pencil"
        case "play": "play.fill"
        case "plus": "plus"
        case "rss": "dot.radiowaves.left.and.right"
        case "search": "magnifyingglass"
        case "send": "paperplane.fill"
        case "share": "square.and.arrow.up"
        case "sort": "arrow.up.arrow.down"
        case "sparkles": "sparkles"
        case "stack": "square.stack"
        case "star": "star"
        case "star-fill": "star.fill"
        case "sun": "sun.max"
        case "tag": "tag"
        case "translate": "character.book.closed"
        case "wand": "wand.and.stars"
        case "weibo": "bubble.left"
        case "x": "xmark"
        case "youtube": "play.rectangle"
        default: name
        }
    }
}

func iconName(for kind: ReaderKind) -> String {
    switch kind {
    case .web: "globe"
    case .rss: "rss"
    case .x: "x"
    case .weibo: "weibo"
    case .youtube: "youtube"
    case .pdf: "doc"
    case .markdown: "markdown"
    case .image: "image"
    case .video: "video"
    }
}

private struct VectorIcon: View {
    let name: String

    static func supports(_ name: String) -> Bool {
        strokePaths(for: name) != nil || !fillPaths(for: name).isEmpty
    }

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 24, y: size.height / 24)
            let strokeStyle = StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)

            for path in Self.strokePaths(for: name) ?? [] {
                context.stroke(path, with: .foreground, style: strokeStyle)
            }

            for path in Self.fillPaths(for: name) {
                context.fill(path, with: .foreground, style: FillStyle(eoFill: true))
            }
        }
    }

    private static func strokePaths(for name: String) -> [Path]? {
        switch name {
        case "inbox":
            return [
                path { p in
                    p.move(to: CGPoint(x: 3, y: 13.5))
                    p.addLine(to: CGPoint(x: 7, y: 13.5))
                    p.addLine(to: CGPoint(x: 8.4, y: 16.3))
                    p.addQuadCurve(to: CGPoint(x: 9.3, y: 16.85), control: CGPoint(x: 8.72, y: 16.85))
                    p.addLine(to: CGPoint(x: 14.7, y: 16.85))
                    p.addQuadCurve(to: CGPoint(x: 15.6, y: 16.3), control: CGPoint(x: 15.28, y: 16.85))
                    p.addLine(to: CGPoint(x: 17, y: 13.5))
                    p.addLine(to: CGPoint(x: 21, y: 13.5))
                },
                path { p in
                    p.move(to: CGPoint(x: 3.2, y: 13.5))
                    p.addLine(to: CGPoint(x: 5.6, y: 6.3))
                    p.addQuadCurve(to: CGPoint(x: 7.5, y: 5), control: CGPoint(x: 6.2, y: 5))
                    p.addLine(to: CGPoint(x: 16.5, y: 5))
                    p.addQuadCurve(to: CGPoint(x: 18.4, y: 6.3), control: CGPoint(x: 17.8, y: 5))
                    p.addLine(to: CGPoint(x: 20.8, y: 13.5))
                    p.addLine(to: CGPoint(x: 20.8, y: 18))
                    p.addQuadCurve(to: CGPoint(x: 18.8, y: 20), control: CGPoint(x: 20.8, y: 20))
                    p.addLine(to: CGPoint(x: 5.2, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 3.2, y: 18), control: CGPoint(x: 3.2, y: 20))
                    p.closeSubpath()
                }
            ]
        case "stack":
            return [
                polygon([CGPoint(x: 12, y: 3.2), CGPoint(x: 20.5, y: 7.8), CGPoint(x: 12, y: 12.4), CGPoint(x: 3.5, y: 7.8)], close: true),
                polyline([CGPoint(x: 4, y: 12), CGPoint(x: 12, y: 16.4), CGPoint(x: 20, y: 12)]),
                polyline([CGPoint(x: 4, y: 16.2), CGPoint(x: 12, y: 20.6), CGPoint(x: 20, y: 16.2)])
            ]
        case "star", "star-fill":
            return name == "star" ? [starPath()] : []
        case "clock":
            return [
                ellipse(x: 3.6, y: 3.6, width: 16.8, height: 16.8),
                polyline([CGPoint(x: 12, y: 7.5), CGPoint(x: 12, y: 12), CGPoint(x: 15.2, y: 14)])
            ]
        case "close":
            return [
                polyline([CGPoint(x: 6, y: 6), CGPoint(x: 18, y: 18)]),
                polyline([CGPoint(x: 18, y: 6), CGPoint(x: 6, y: 18)])
            ]
        case "archive":
            return [
                roundedRect(x: 3.5, y: 4.5, width: 17, height: 4, radius: 1.3),
                path { p in
                    p.move(to: CGPoint(x: 5, y: 8.5))
                    p.addLine(to: CGPoint(x: 5, y: 18))
                    p.addQuadCurve(to: CGPoint(x: 7, y: 20), control: CGPoint(x: 5, y: 20))
                    p.addLine(to: CGPoint(x: 17, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 19, y: 18), control: CGPoint(x: 19, y: 20))
                    p.addLine(to: CGPoint(x: 19, y: 8.5))
                },
                polyline([CGPoint(x: 10, y: 12), CGPoint(x: 14, y: 12)])
            ]
        case "rss":
            return [
                arc(center: CGPoint(x: 5, y: 19.6), radius: 8, start: -90, end: 0),
                arc(center: CGPoint(x: 5, y: 19.6), radius: 14, start: -90, end: 0)
            ]
        case "weibo":
            return [
                path { p in
                    p.move(to: CGPoint(x: 19.5, y: 12.2))
                    p.addQuadCurve(to: CGPoint(x: 10.9, y: 18.5), control: CGPoint(x: 19.5, y: 18.5))
                    p.addQuadCurve(to: CGPoint(x: 7.9, y: 18.1), control: CGPoint(x: 9.2, y: 18.5))
                    p.addLine(to: CGPoint(x: 4, y: 19.4))
                    p.addLine(to: CGPoint(x: 5.4, y: 15.9))
                    p.addQuadCurve(to: CGPoint(x: 3.4, y: 11.9), control: CGPoint(x: 3.4, y: 14.2))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 5.6), control: CGPoint(x: 3.4, y: 5.6))
                    p.addQuadCurve(to: CGPoint(x: 19.5, y: 12.2), control: CGPoint(x: 19.5, y: 5.6))
                }
            ]
        case "youtube":
            return [roundedRect(x: 2.5, y: 6, width: 19, height: 12, radius: 3.4)]
        case "video":
            return [
                roundedRect(x: 3, y: 5.5, width: 13, height: 13, radius: 2.6),
                path { p in
                    p.move(to: CGPoint(x: 16, y: 10))
                    p.addLine(to: CGPoint(x: 21, y: 7))
                    p.addLine(to: CGPoint(x: 21, y: 17))
                    p.addLine(to: CGPoint(x: 16, y: 14))
                }
            ]
        case "folder":
            return [
                path { p in
                    p.move(to: CGPoint(x: 3.5, y: 7.6))
                    p.addQuadCurve(to: CGPoint(x: 5.5, y: 5.6), control: CGPoint(x: 3.5, y: 5.6))
                    p.addLine(to: CGPoint(x: 8.8, y: 5.6))
                    p.addQuadCurve(to: CGPoint(x: 10.2, y: 6.2), control: CGPoint(x: 9.6, y: 5.6))
                    p.addLine(to: CGPoint(x: 11.1, y: 7.1))
                    p.addQuadCurve(to: CGPoint(x: 12.5, y: 7.7), control: CGPoint(x: 11.7, y: 7.7))
                    p.addLine(to: CGPoint(x: 18, y: 7.7))
                    p.addQuadCurve(to: CGPoint(x: 20, y: 9.7), control: CGPoint(x: 20, y: 7.7))
                    p.addLine(to: CGPoint(x: 20, y: 17))
                    p.addQuadCurve(to: CGPoint(x: 18, y: 19), control: CGPoint(x: 20, y: 19))
                    p.addLine(to: CGPoint(x: 5.5, y: 19))
                    p.addQuadCurve(to: CGPoint(x: 3.5, y: 17), control: CGPoint(x: 3.5, y: 19))
                    p.closeSubpath()
                }
            ]
        case "tag":
            return [
                path { p in
                    p.move(to: CGPoint(x: 12.7, y: 3.5))
                    p.addLine(to: CGPoint(x: 5, y: 3.5))
                    p.addQuadCurve(to: CGPoint(x: 3.5, y: 5), control: CGPoint(x: 3.5, y: 3.5))
                    p.addLine(to: CGPoint(x: 3.5, y: 12.5))
                    p.addQuadCurve(to: CGPoint(x: 3.94, y: 13.56), control: CGPoint(x: 3.5, y: 13.12))
                    p.addLine(to: CGPoint(x: 11.74, y: 21.36))
                    p.addQuadCurve(to: CGPoint(x: 13.86, y: 21.36), control: CGPoint(x: 12.8, y: 22.42))
                    p.addLine(to: CGPoint(x: 20.36, y: 14.86))
                    p.addQuadCurve(to: CGPoint(x: 20.36, y: 12.74), control: CGPoint(x: 21.42, y: 13.8))
                    p.addLine(to: CGPoint(x: 12.56, y: 4.94))
                    p.addQuadCurve(to: CGPoint(x: 12.7, y: 3.5), control: CGPoint(x: 12.7, y: 4.3))
                }
            ]
        case "search":
            return [
                ellipse(x: 4.1, y: 4.1, width: 12.8, height: 12.8),
                polyline([CGPoint(x: 15.4, y: 15.4), CGPoint(x: 20, y: 20)])
            ]
        case "plus":
            return [polyline([CGPoint(x: 12, y: 5), CGPoint(x: 12, y: 19)]), polyline([CGPoint(x: 5, y: 12), CGPoint(x: 19, y: 12)])]
        case "minus":
            return [polyline([CGPoint(x: 5, y: 12), CGPoint(x: 19, y: 12)])]
        case "gear":
            return [
                ellipse(x: 9, y: 9, width: 6, height: 6),
                path { p in
                    p.move(to: CGPoint(x: 19.1, y: 14))
                    p.addQuadCurve(to: CGPoint(x: 19.42, y: 15.77), control: CGPoint(x: 18.8, y: 14.7))
                    p.addLine(to: CGPoint(x: 19.48, y: 15.83))
                    p.addQuadCurve(to: CGPoint(x: 16.65, y: 18.66), control: CGPoint(x: 21.1, y: 17.4))
                    p.addLine(to: CGPoint(x: 16.59, y: 18.6))
                    p.addQuadCurve(to: CGPoint(x: 13.87, y: 19.73), control: CGPoint(x: 14.7, y: 17.8))
                    p.addLine(to: CGPoint(x: 13.87, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 9.87, y: 20), control: CGPoint(x: 13.87, y: 22))
                    p.addLine(to: CGPoint(x: 9.87, y: 19.91))
                    p.addQuadCurve(to: CGPoint(x: 7.15, y: 18.78), control: CGPoint(x: 9.0, y: 17.8))
                    p.addLine(to: CGPoint(x: 7.09, y: 18.84))
                    p.addQuadCurve(to: CGPoint(x: 4.26, y: 16.01), control: CGPoint(x: 5.5, y: 20.4))
                    p.addLine(to: CGPoint(x: 4.32, y: 15.95))
                    p.addQuadCurve(to: CGPoint(x: 4.5, y: 14), control: CGPoint(x: 5.2, y: 14.7))
                    p.addLine(to: CGPoint(x: 4.4, y: 14))
                    p.addQuadCurve(to: CGPoint(x: 4.4, y: 10), control: CGPoint(x: 2.4, y: 14))
                    p.addLine(to: CGPoint(x: 4.49, y: 10))
                    p.addQuadCurve(to: CGPoint(x: 5.62, y: 7.28), control: CGPoint(x: 6.2, y: 9.1))
                    p.addLine(to: CGPoint(x: 5.56, y: 7.22))
                    p.addQuadCurve(to: CGPoint(x: 8.39, y: 4.39), control: CGPoint(x: 4, y: 5.6))
                    p.addLine(to: CGPoint(x: 8.45, y: 4.45))
                    p.addQuadCurve(to: CGPoint(x: 10, y: 4.5), control: CGPoint(x: 9.2, y: 5.1))
                    p.addLine(to: CGPoint(x: 10, y: 4.4))
                    p.addQuadCurve(to: CGPoint(x: 14, y: 4.4), control: CGPoint(x: 10, y: 2.4))
                    p.addLine(to: CGPoint(x: 14, y: 4.49))
                    p.addQuadCurve(to: CGPoint(x: 15.55, y: 4.45), control: CGPoint(x: 14.8, y: 5.1))
                    p.addLine(to: CGPoint(x: 15.61, y: 4.39))
                    p.addQuadCurve(to: CGPoint(x: 18.44, y: 7.22), control: CGPoint(x: 20, y: 5.6))
                    p.addLine(to: CGPoint(x: 18.38, y: 7.28))
                    p.addQuadCurve(to: CGPoint(x: 19.5, y: 10), control: CGPoint(x: 17.8, y: 9.1))
                    p.addLine(to: CGPoint(x: 19.6, y: 10))
                    p.addQuadCurve(to: CGPoint(x: 19.6, y: 14), control: CGPoint(x: 21.6, y: 10))
                    p.closeSubpath()
                }
            ]
        case "panel-right":
            return [roundedRect(x: 3, y: 4.5, width: 18, height: 15, radius: 2.6), polyline([CGPoint(x: 14.8, y: 4.7), CGPoint(x: 14.8, y: 19.3)])]
        case "sun":
            return [
                ellipse(x: 8, y: 8, width: 8, height: 8),
                polyline([CGPoint(x: 12, y: 2.6), CGPoint(x: 12, y: 4.6)]),
                polyline([CGPoint(x: 12, y: 19.4), CGPoint(x: 12, y: 21.4)]),
                polyline([CGPoint(x: 2.6, y: 12), CGPoint(x: 4.6, y: 12)]),
                polyline([CGPoint(x: 19.4, y: 12), CGPoint(x: 21.4, y: 12)]),
                polyline([CGPoint(x: 5.1, y: 5.1), CGPoint(x: 6.5, y: 6.5)]),
                polyline([CGPoint(x: 17.5, y: 17.5), CGPoint(x: 18.9, y: 18.9)]),
                polyline([CGPoint(x: 18.9, y: 5.1), CGPoint(x: 17.5, y: 6.5)]),
                polyline([CGPoint(x: 6.5, y: 17.5), CGPoint(x: 5.1, y: 18.9)])
            ]
        case "moon":
            return [
                path { p in
                    p.move(to: CGPoint(x: 20, y: 13.6))
                    p.addQuadCurve(to: CGPoint(x: 10.4, y: 4), control: CGPoint(x: 13.8, y: 16.0))
                    p.addQuadCurve(to: CGPoint(x: 20, y: 13.6), control: CGPoint(x: 13.6, y: 15.7))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 20.4), control: CGPoint(x: 16.9, y: 20.3))
                    p.addQuadCurve(to: CGPoint(x: 3.6, y: 12), control: CGPoint(x: 3.6, y: 20.4))
                    p.addQuadCurve(to: CGPoint(x: 10.4, y: 4), control: CGPoint(x: 3.6, y: 6.6))
                }
            ]
        case "send":
            return [
                polyline([CGPoint(x: 12, y: 19), CGPoint(x: 12, y: 5.5)]),
                polyline([CGPoint(x: 6.5, y: 11), CGPoint(x: 12, y: 5.5), CGPoint(x: 17.5, y: 11)])
            ]
        case "link":
            return [
                polyline([CGPoint(x: 9.5, y: 14.5), CGPoint(x: 14.5, y: 9.5)]),
                path { p in
                    p.move(to: CGPoint(x: 8.2, y: 12.2))
                    p.addLine(to: CGPoint(x: 6.2, y: 14.2))
                    p.addQuadCurve(to: CGPoint(x: 11, y: 19), control: CGPoint(x: 3.8, y: 16.6))
                    p.addLine(to: CGPoint(x: 13, y: 17))
                },
                path { p in
                    p.move(to: CGPoint(x: 15.8, y: 11.8))
                    p.addLine(to: CGPoint(x: 17.8, y: 9.8))
                    p.addQuadCurve(to: CGPoint(x: 13, y: 5), control: CGPoint(x: 20.2, y: 7.4))
                    p.addLine(to: CGPoint(x: 11, y: 7))
                }
            ]
        case "paperclip":
            return [
                path { p in
                    p.move(to: CGPoint(x: 20, y: 11.6))
                    p.addLine(to: CGPoint(x: 11.7, y: 19.9))
                    p.addQuadCurve(to: CGPoint(x: 5.3, y: 13.5), control: CGPoint(x: 8.5, y: 23.1))
                    p.addLine(to: CGPoint(x: 13.9, y: 4.9))
                    p.addQuadCurve(to: CGPoint(x: 18.2, y: 9.2), control: CGPoint(x: 16.05, y: 2.75))
                    p.addLine(to: CGPoint(x: 9.7, y: 17.7))
                    p.addQuadCurve(to: CGPoint(x: 7.6, y: 15.6), control: CGPoint(x: 8.65, y: 18.75))
                    p.addLine(to: CGPoint(x: 15.4, y: 7.8))
                }
            ]
        case "doc":
            return [
                path { p in
                    p.move(to: CGPoint(x: 6, y: 3.5))
                    p.addLine(to: CGPoint(x: 13, y: 3.5))
                    p.addLine(to: CGPoint(x: 18, y: 8.5))
                    p.addLine(to: CGPoint(x: 18, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 17, y: 21), control: CGPoint(x: 18, y: 21))
                    p.addLine(to: CGPoint(x: 6, y: 21))
                    p.addQuadCurve(to: CGPoint(x: 5, y: 20), control: CGPoint(x: 5, y: 21))
                    p.addLine(to: CGPoint(x: 5, y: 4.5))
                    p.addQuadCurve(to: CGPoint(x: 6, y: 3.5), control: CGPoint(x: 5, y: 3.5))
                    p.closeSubpath()
                },
                polyline([CGPoint(x: 13, y: 3.5), CGPoint(x: 13, y: 9), CGPoint(x: 18, y: 9)]),
                polyline([CGPoint(x: 8.5, y: 13.5), CGPoint(x: 15.5, y: 13.5)]),
                polyline([CGPoint(x: 8.5, y: 16.5), CGPoint(x: 13.5, y: 16.5)])
            ]
        case "image":
            return [
                roundedRect(x: 3.5, y: 4.5, width: 17, height: 15, radius: 2.6),
                ellipse(x: 7.4, y: 8.4, width: 3.2, height: 3.2),
                polyline([CGPoint(x: 4.5, y: 17.5), CGPoint(x: 9, y: 13.5), CGPoint(x: 12, y: 16), CGPoint(x: 16, y: 12.5), CGPoint(x: 20, y: 17)])
            ]
        case "markdown":
            return [
                roundedRect(x: 2.5, y: 6, width: 19, height: 12, radius: 2.6),
                polyline([CGPoint(x: 6, y: 15), CGPoint(x: 6, y: 9), CGPoint(x: 9, y: 12), CGPoint(x: 12, y: 9), CGPoint(x: 12, y: 15)]),
                polyline([CGPoint(x: 17, y: 9), CGPoint(x: 17, y: 15)]),
                polyline([CGPoint(x: 14.8, y: 12.8), CGPoint(x: 17, y: 15), CGPoint(x: 19.2, y: 12.8)])
            ]
        case "calendar":
            return [
                roundedRect(x: 3.5, y: 5, width: 17, height: 15, radius: 2.4),
                polyline([CGPoint(x: 3.5, y: 9.5), CGPoint(x: 20.5, y: 9.5)]),
                polyline([CGPoint(x: 8, y: 3.5), CGPoint(x: 8, y: 6.5)]),
                polyline([CGPoint(x: 16, y: 3.5), CGPoint(x: 16, y: 6.5)])
            ]
        case "copy":
            return [
                roundedRect(x: 8.5, y: 8.5, width: 11, height: 11, radius: 2.4),
                path { p in
                    p.move(to: CGPoint(x: 5.8, y: 15.5))
                    p.addLine(to: CGPoint(x: 5, y: 15.5))
                    p.addQuadCurve(to: CGPoint(x: 3.5, y: 14), control: CGPoint(x: 3.5, y: 15.5))
                    p.addLine(to: CGPoint(x: 3.5, y: 5))
                    p.addQuadCurve(to: CGPoint(x: 5, y: 3.5), control: CGPoint(x: 3.5, y: 3.5))
                    p.addLine(to: CGPoint(x: 14, y: 3.5))
                    p.addQuadCurve(to: CGPoint(x: 15.5, y: 5), control: CGPoint(x: 15.5, y: 3.5))
                    p.addLine(to: CGPoint(x: 15.5, y: 5.6))
                }
            ]
        case "bookmark":
            return [
                path { p in
                    p.move(to: CGPoint(x: 6, y: 4.5))
                    p.addLine(to: CGPoint(x: 18, y: 4.5))
                    p.addQuadCurve(to: CGPoint(x: 18.5, y: 5), control: CGPoint(x: 18.5, y: 4.5))
                    p.addLine(to: CGPoint(x: 18.5, y: 20))
                    p.addLine(to: CGPoint(x: 12, y: 16))
                    p.addLine(to: CGPoint(x: 5.5, y: 20))
                    p.addLine(to: CGPoint(x: 5.5, y: 5))
                    p.addQuadCurve(to: CGPoint(x: 6, y: 4.5), control: CGPoint(x: 5.5, y: 4.5))
                    p.closeSubpath()
                }
            ]
        case "chat":
            return [
                path { p in
                    p.move(to: CGPoint(x: 20, y: 11.6))
                    p.addQuadCurve(to: CGPoint(x: 12.2, y: 18.2), control: CGPoint(x: 20, y: 18.2))
                    p.addQuadCurve(to: CGPoint(x: 9.2, y: 17.6), control: CGPoint(x: 10.8, y: 18.2))
                    p.addLine(to: CGPoint(x: 4, y: 19.2))
                    p.addLine(to: CGPoint(x: 5.7, y: 15))
                    p.addQuadCurve(to: CGPoint(x: 4.4, y: 11.6), control: CGPoint(x: 4.4, y: 13.6))
                    p.addQuadCurve(to: CGPoint(x: 12.2, y: 5), control: CGPoint(x: 4.4, y: 5))
                    p.addQuadCurve(to: CGPoint(x: 20, y: 11.6), control: CGPoint(x: 20, y: 5))
                }
            ]
        case "translate":
            return [
                polyline([CGPoint(x: 3, y: 5.5), CGPoint(x: 11.5, y: 5.5)]),
                polyline([CGPoint(x: 7, y: 3.5), CGPoint(x: 7, y: 5.5)]),
                path { p in
                    p.move(to: CGPoint(x: 7, y: 5.5))
                    p.addQuadCurve(to: CGPoint(x: 3, y: 14.3), control: CGPoint(x: 7, y: 11))
                },
                path { p in
                    p.move(to: CGPoint(x: 4.6, y: 9.2))
                    p.addQuadCurve(to: CGPoint(x: 9.8, y: 13.8), control: CGPoint(x: 6, y: 12))
                },
                polyline([CGPoint(x: 12.5, y: 20.5), CGPoint(x: 16.5, y: 11.5), CGPoint(x: 20.5, y: 20.5)]),
                polyline([CGPoint(x: 14, y: 17.5), CGPoint(x: 19, y: 17.5)])
            ]
        case "highlighter":
            return [
                path { p in
                    p.move(to: CGPoint(x: 9.5, y: 13.8))
                    p.addLine(to: CGPoint(x: 8.5, y: 18))
                    p.addLine(to: CGPoint(x: 12.7, y: 17))
                    p.addLine(to: CGPoint(x: 20.4, y: 9))
                    p.addQuadCurve(to: CGPoint(x: 17.7, y: 6.3), control: CGPoint(x: 19.05, y: 4.95))
                    p.closeSubpath()
                },
                polyline([CGPoint(x: 14.5, y: 6.8), CGPoint(x: 17.9, y: 10.2)]),
                polyline([CGPoint(x: 7, y: 21), CGPoint(x: 13, y: 21)])
            ]
        case "pencil":
            return [
                path { p in
                    p.move(to: CGPoint(x: 4, y: 20))
                    p.addLine(to: CGPoint(x: 5, y: 16))
                    p.addLine(to: CGPoint(x: 16.4, y: 4.6))
                    p.addQuadCurve(to: CGPoint(x: 19.2, y: 7.4), control: CGPoint(x: 17.8, y: 3.2))
                    p.addLine(to: CGPoint(x: 7.8, y: 19))
                    p.closeSubpath()
                },
                polyline([CGPoint(x: 14, y: 7), CGPoint(x: 17, y: 10)])
            ]
        case "check":
            return [polyline([CGPoint(x: 5, y: 12.6), CGPoint(x: 9.4, y: 17), CGPoint(x: 19, y: 7.2)])]
        case "check-circle":
            return [ellipse(x: 3.5, y: 3.5, width: 17, height: 17), polyline([CGPoint(x: 8.2, y: 12.3), CGPoint(x: 10.9, y: 15), CGPoint(x: 16, y: 9.5)])]
        case "ellipsis":
            return []
        case "share":
            return [
                polyline([CGPoint(x: 12, y: 3.6), CGPoint(x: 15.4, y: 7)]),
                polyline([CGPoint(x: 12, y: 3.6), CGPoint(x: 8.6, y: 7)]),
                polyline([CGPoint(x: 12, y: 3.6), CGPoint(x: 12, y: 15)]),
                path { p in
                    p.move(to: CGPoint(x: 6.5, y: 11))
                    p.addLine(to: CGPoint(x: 5.5, y: 11))
                    p.addQuadCurve(to: CGPoint(x: 4, y: 12.6), control: CGPoint(x: 4, y: 11))
                    p.addLine(to: CGPoint(x: 4, y: 19))
                    p.addQuadCurve(to: CGPoint(x: 5.5, y: 20.5), control: CGPoint(x: 4, y: 20.5))
                    p.addLine(to: CGPoint(x: 18.5, y: 20.5))
                    p.addQuadCurve(to: CGPoint(x: 20, y: 19), control: CGPoint(x: 20, y: 20.5))
                    p.addLine(to: CGPoint(x: 20, y: 12.6))
                    p.addQuadCurve(to: CGPoint(x: 18.5, y: 11), control: CGPoint(x: 20, y: 11))
                    p.addLine(to: CGPoint(x: 17, y: 11))
                }
            ]
        case "globe":
            return [
                ellipse(x: 3.6, y: 3.6, width: 16.8, height: 16.8),
                polyline([CGPoint(x: 3.6, y: 12), CGPoint(x: 20.4, y: 12)]),
                path { p in
                    p.move(to: CGPoint(x: 12, y: 3.6))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 20.4), control: CGPoint(x: 16, y: 12))
                },
                path { p in
                    p.move(to: CGPoint(x: 12, y: 3.6))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 20.4), control: CGPoint(x: 8, y: 12))
                }
            ]
        case "list":
            return [
                polyline([CGPoint(x: 8.5, y: 6.5), CGPoint(x: 19.5, y: 6.5)]),
                polyline([CGPoint(x: 8.5, y: 12), CGPoint(x: 19.5, y: 12)]),
                polyline([CGPoint(x: 8.5, y: 17.5), CGPoint(x: 19.5, y: 17.5)])
            ]
        case "wand":
            return [
                polyline([CGPoint(x: 5, y: 19), CGPoint(x: 14.5, y: 9.5)]),
                polyline([CGPoint(x: 16, y: 6), CGPoint(x: 18.5, y: 8.5)])
            ]
        case "eye":
            return [
                path { p in
                    p.move(to: CGPoint(x: 2.6, y: 12))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 5.6), control: CGPoint(x: 6, y: 5.6))
                    p.addQuadCurve(to: CGPoint(x: 21.4, y: 12), control: CGPoint(x: 18, y: 5.6))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 18.4), control: CGPoint(x: 18, y: 18.4))
                    p.addQuadCurve(to: CGPoint(x: 2.6, y: 12), control: CGPoint(x: 6, y: 18.4))
                    p.closeSubpath()
                },
                ellipse(x: 9, y: 9, width: 6, height: 6)
            ]
        case "sort":
            return [
                polyline([CGPoint(x: 7, y: 4.5), CGPoint(x: 7, y: 19.5)]),
                polyline([CGPoint(x: 7, y: 19.5), CGPoint(x: 4, y: 16.5)]),
                polyline([CGPoint(x: 7, y: 19.5), CGPoint(x: 10, y: 16.5)]),
                polyline([CGPoint(x: 13, y: 7), CGPoint(x: 20, y: 7)]),
                polyline([CGPoint(x: 13, y: 12), CGPoint(x: 18, y: 12)]),
                polyline([CGPoint(x: 13, y: 17), CGPoint(x: 16, y: 17)])
            ]
        case "chev":
            return [polyline([CGPoint(x: 9, y: 5.5), CGPoint(x: 15.5, y: 12), CGPoint(x: 9, y: 18.5)])]
        case "play":
            return []
        default:
            return nil
        }
    }

    private static func fillPaths(for name: String) -> [Path] {
        switch name {
        case "dot":
            return [ellipse(x: 8, y: 8, width: 8, height: 8)]
        case "star-fill":
            return [starPath()]
        case "rss":
            return [ellipse(x: 4.2, y: 16.4, width: 3.4, height: 3.4)]
        case "youtube":
            return [polygon([CGPoint(x: 10.4, y: 9.2), CGPoint(x: 15.6, y: 12), CGPoint(x: 10.4, y: 14.8)], close: true)]
        case "x":
            return [
                path { p in
                    p.move(to: CGPoint(x: 18.24, y: 2.5))
                    p.addLine(to: CGPoint(x: 21.54, y: 2.5))
                    p.addLine(to: CGPoint(x: 14.34, y: 10.73))
                    p.addLine(to: CGPoint(x: 23, y: 21.5))
                    p.addLine(to: CGPoint(x: 16.37, y: 21.5))
                    p.addLine(to: CGPoint(x: 11.17, y: 14.71))
                    p.addLine(to: CGPoint(x: 5.24, y: 21.5))
                    p.addLine(to: CGPoint(x: 1.93, y: 21.5))
                    p.addLine(to: CGPoint(x: 9.63, y: 12.7))
                    p.addLine(to: CGPoint(x: 1.5, y: 2.5))
                    p.addLine(to: CGPoint(x: 8.3, y: 2.5))
                    p.addLine(to: CGPoint(x: 12.99, y: 8.7))
                    p.closeSubpath()
                    p.move(to: CGPoint(x: 16.06, y: 19.5))
                    p.addLine(to: CGPoint(x: 17.89, y: 19.5))
                    p.addLine(to: CGPoint(x: 7, y: 4.4))
                    p.addLine(to: CGPoint(x: 5.04, y: 4.4))
                    p.closeSubpath()
                }
            ]
        case "tag":
            return [ellipse(x: 6.7, y: 6.7, width: 2.6, height: 2.6)]
        case "sparkles":
            return [
                polygon([CGPoint(x: 12, y: 3.2), CGPoint(x: 13.7, y: 7.7), CGPoint(x: 18.2, y: 9.4), CGPoint(x: 13.7, y: 11.1), CGPoint(x: 12, y: 15.6), CGPoint(x: 10.3, y: 11.1), CGPoint(x: 5.8, y: 9.4), CGPoint(x: 10.3, y: 7.7)], close: true),
                polygon([CGPoint(x: 18.4, y: 14.2), CGPoint(x: 19.05, y: 15.95), CGPoint(x: 20.8, y: 16.6), CGPoint(x: 19.05, y: 17.25), CGPoint(x: 18.4, y: 19), CGPoint(x: 17.75, y: 17.25), CGPoint(x: 16, y: 16.6), CGPoint(x: 17.75, y: 15.95)], close: true)
            ]
        case "wand":
            return [
                polygon([CGPoint(x: 14, y: 4), CGPoint(x: 14.6, y: 5.6), CGPoint(x: 16.2, y: 6.2), CGPoint(x: 14.6, y: 6.8), CGPoint(x: 14, y: 8.4), CGPoint(x: 13.4, y: 6.8), CGPoint(x: 11.8, y: 6.2), CGPoint(x: 13.4, y: 5.6)], close: true),
                polygon([CGPoint(x: 19.2, y: 11.4), CGPoint(x: 19.65, y: 12.6), CGPoint(x: 20.85, y: 13.05), CGPoint(x: 19.65, y: 13.5), CGPoint(x: 19.2, y: 14.7), CGPoint(x: 18.75, y: 13.5), CGPoint(x: 17.55, y: 13.05), CGPoint(x: 18.75, y: 12.6)], close: true)
            ]
        case "ellipsis":
            return [
                ellipse(x: 3.9, y: 10.4, width: 3.2, height: 3.2),
                ellipse(x: 10.4, y: 10.4, width: 3.2, height: 3.2),
                ellipse(x: 16.9, y: 10.4, width: 3.2, height: 3.2)
            ]
        case "play":
            return [polygon([CGPoint(x: 7, y: 5), CGPoint(x: 19, y: 12), CGPoint(x: 7, y: 19)], close: true)]
        case "list":
            return [
                ellipse(x: 4.0, y: 6.1, width: 0.6, height: 0.6),
                ellipse(x: 4.0, y: 11.6, width: 0.6, height: 0.6),
                ellipse(x: 4.0, y: 17.1, width: 0.6, height: 0.6)
            ]
        default:
            return []
        }
    }

    private static func path(_ build: (inout Path) -> Void) -> Path {
        var path = Path()
        build(&path)
        return path
    }

    private static func polyline(_ points: [CGPoint]) -> Path {
        path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            for point in points.dropFirst() {
                p.addLine(to: point)
            }
        }
    }

    private static func polygon(_ points: [CGPoint], close: Bool) -> Path {
        path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            for point in points.dropFirst() {
                p.addLine(to: point)
            }
            if close {
                p.closeSubpath()
            }
        }
    }

    private static func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius)
    }

    private static func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height))
    }

    private static func arc(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> Path {
        path { p in
            p.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        }
    }

    private static func starPath() -> Path {
        polygon([
            CGPoint(x: 12, y: 3.6),
            CGPoint(x: 14.55, y: 8.9),
            CGPoint(x: 20.4, y: 9.7),
            CGPoint(x: 16.15, y: 13.75),
            CGPoint(x: 17.2, y: 19.55),
            CGPoint(x: 12, y: 16.9),
            CGPoint(x: 6.8, y: 19.55),
            CGPoint(x: 7.85, y: 13.75),
            CGPoint(x: 3.6, y: 9.7),
            CGPoint(x: 9.45, y: 8.9)
        ], close: true)
    }
}
