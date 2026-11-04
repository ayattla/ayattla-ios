import UIKit
import CoreGraphics

/// The site's four animated backgrounds (a_stars, a_aurora, a_dust, a_dawn), drawn frame by frame
/// on the device, and the "حركة هادئة" slow zoom for a photo from the device.
enum MotionStyle: String, CaseIterable, Identifiable, Codable {
    case stars = "a_stars", aurora = "a_aurora", dust = "a_dust", dawn = "a_dawn"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .stars: "نجوم هادئة"
        case .aurora: "شفق زمردي"
        case .dust: "غبار ذهبي"
        case .dawn: "فجر دافئ"
        }
    }
}

enum MotionBackground {
    case style(MotionStyle)
    case photo(UIImage, slowZoom: Bool)
    /// A real video from the site's library (Pixabay/Pexels), looped under the text.
    case video(VideoFrames, poster: UIImage?)

    /// Draws the background at time `t` (seconds) of a clip lasting `total` seconds.
    /// The context uses Core Graphics coordinates (origin at the bottom left).
    func draw(in ctx: CGContext, size: CGSize, t: Double, total: Double) {
        switch self {
        case .style(let s): Self.draw(s, ctx, size, t)
        case .photo(let img, let zoom): Self.drawPhoto(img, ctx, size, progress: total > 0 ? t / total : 0, zoom: zoom)
        case .video(let v, let poster):
            if let f = v.frame(at: t) { Self.drawFill(f, ctx, size, zoom: 1) }
            else if let cg = poster?.cgImage { Self.drawFill(cg, ctx, size, zoom: 1) }
            ctx.setFillColor(Self.rgb(0x000000, 0.42))
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func drawFill(_ cg: CGImage, _ ctx: CGContext, _ size: CGSize, zoom z: CGFloat) {
        let iw = CGFloat(cg.width), ih = CGFloat(cg.height)
        let fill = max(size.width / iw, size.height / ih)
        let dw = iw * fill * z, dh = ih * fill * z
        ctx.draw(cg, in: CGRect(x: (size.width - dw) / 2, y: (size.height - dh) / 2, width: dw, height: dh))
    }

    /// One still for previews and thumbnails.
    func still(size: CGSize, t: Double = 1.5) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { r in
            let ctx = r.cgContext
            ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)   // to Core Graphics coordinates
            draw(in: ctx, size: size, t: t, total: 10)
        }
    }

    // MARK: Drawing

    private static func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    private static func vertical(_ ctx: CGContext, _ size: CGSize, top: UInt32, bottom: UInt32) {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [rgb(bottom), rgb(top)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }

    private static func glow(_ ctx: CGContext, at p: CGPoint, radius: CGFloat, color: UInt32, alpha: CGFloat) {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [rgb(color, alpha), rgb(color, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: radius, options: [])
    }

    /// Deterministic pseudo-random numbers in 0..<1 so every export of the same clip looks the same.
    private static func r(_ i: Int, _ k: Int) -> CGFloat {
        var x = UInt64(i &* 73_856_093 ^ k &* 19_349_663) &+ 0x9E37_79B9_7F4A_7C15
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat(x >> 11) / CGFloat(1 << 53)
    }

    private static func draw(_ s: MotionStyle, _ ctx: CGContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height, u = min(w, h)
        switch s {
        case .stars:
            vertical(ctx, size, top: 0x0B1426, bottom: 0x1B2A3F)
            for i in 0..<140 {
                let p = CGPoint(x: r(i, 1) * w, y: r(i, 2) * h)
                let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.6 + Double(r(i, 3)) * 1.6) + Double(r(i, 4)) * 6.28))
                let size = (0.8 + r(i, 5) * 2.2) * u / 1080
                ctx.setFillColor(rgb(0xFFFFFF, CGFloat(twinkle) * 0.9))
                ctx.fillEllipse(in: CGRect(x: p.x - size, y: p.y - size, width: size * 2, height: size * 2))
            }
            glow(ctx, at: CGPoint(x: w * 0.5, y: h * 0.15), radius: u * 0.8, color: 0x2F6B3B, alpha: 0.25)
        case .aurora:
            vertical(ctx, size, top: 0x06140C, bottom: 0x10261A)
            for i in 0..<3 {
                let phase = Double(i) * 2.1
                let p = CGPoint(x: w * (0.5 + 0.35 * CGFloat(sin(t * 0.18 + phase))),
                                y: h * (0.55 + 0.25 * CGFloat(cos(t * 0.13 + phase))))
                glow(ctx, at: p, radius: u * (0.7 + 0.15 * CGFloat(i)), color: [0x2E9145, 0x3FB59A, 0x1F6B4F][i], alpha: 0.45)
            }
        case .dust:
            vertical(ctx, size, top: 0x1E1608, bottom: 0x3A2A12)
            glow(ctx, at: CGPoint(x: w * 0.5, y: h * 0.5), radius: u * 0.9, color: 0x8A6A2A, alpha: 0.35)
            for i in 0..<90 {
                let speed = 0.01 + Double(r(i, 6)) * 0.03
                let y = (Double(r(i, 2)) + t * speed).truncatingRemainder(dividingBy: 1.0)
                let x = r(i, 1) + 0.02 * CGFloat(sin(t * 0.5 + Double(i)))
                let size = (1 + r(i, 5) * 3) * u / 1080
                let a = 0.25 + 0.55 * r(i, 7)
                ctx.setFillColor(rgb(0xF3D27A, a))
                ctx.fillEllipse(in: CGRect(x: x * w - size, y: CGFloat(y) * h - size, width: size * 2, height: size * 2))
            }
        case .dawn:
            let k = CGFloat(0.5 + 0.5 * sin(t * 0.12))
            vertical(ctx, size, top: 0x1F3550, bottom: k > 0.5 ? 0xC98D5A : 0xB07A4E)
            glow(ctx, at: CGPoint(x: w * 0.5, y: h * (0.12 + 0.06 * k)), radius: u * 0.9, color: 0xF3C27A, alpha: 0.55)
            glow(ctx, at: CGPoint(x: w * 0.5, y: h * 0.9), radius: u * 0.7, color: 0x0E1A2A, alpha: 0.6)
        }
    }

    private static func drawPhoto(_ img: UIImage, _ ctx: CGContext, _ size: CGSize, progress: Double, zoom: Bool) {
        guard let cg = img.cgImage else { return }
        let iw = CGFloat(cg.width), ih = CGFloat(cg.height)
        let fill = max(size.width / iw, size.height / ih)
        let z = zoom ? 1 + 0.08 * CGFloat(min(max(progress, 0), 1)) : 1
        let dw = iw * fill * z, dh = ih * fill * z
        ctx.draw(cg, in: CGRect(x: (size.width - dw) / 2, y: (size.height - dh) / 2, width: dw, height: dh))
        ctx.setFillColor(rgb(0x000000, 0.45))
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}

extension UIImage {
    /// Redrawn with .up orientation (photos from the library often carry a rotation flag that
    /// Core Graphics ignores), scaled so the long side is at most `maxSide` pixels.
    func uprightForVideo(maxSide: CGFloat = 2160) -> UIImage {
        let s = min(1, maxSide / max(size.width * scale, size.height * scale))
        let target = CGSize(width: size.width * scale * s, height: size.height * scale * s)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: target, format: f).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
