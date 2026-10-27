import CoreGraphics
import Foundation
import UIKit

// The Scene module's colour, randomness and CoreGraphics helpers. Everything here is pure (no SpriteKit, no actor
// isolation), so the cached-texture closures, `TrapArt` and SwiftUI can all call it.

/// Colour helpers on the shared `RGBA`, as plain functions (no extension on a shared type, so nothing can clash with
/// another module's helpers).
enum BogPaint {
    static func ui(_ c: RGBA) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    static func ui(_ c: RGBA, alpha: CGFloat) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: alpha)
    }

    static func cg(_ c: RGBA, _ alpha: Double = 1) -> CGColor {
        CGColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a * alpha))
    }

    static func lighter(_ c: RGBA, _ t: Double) -> RGBA { c.mixed(with: RGBA(1, 1, 1, c.a), t) }
    static func darker(_ c: RGBA, _ t: Double) -> RGBA { c.mixed(with: RGBA(0, 0, 0, c.a), t) }
    static func alpha(_ c: RGBA, _ a: Double) -> RGBA { RGBA(c.r, c.g, c.b, a) }

    /// Component-wise product (a light tint applied to a colour).
    static func multiply(_ a: RGBA, _ b: RGBA) -> RGBA { RGBA(a.r * b.r, a.g * b.g, a.b * b.b, a.a) }

    /// WCAG relative luminance (sRGB).
    static func luminance(_ c: RGBA) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// WCAG contrast ratio (1…21).
    static func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

/// Small maths used all over the scene.
enum BogMath {
    static func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
    static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }

    static func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        guard b != a else { return x < a ? 0 : 1 }
        let t = clamp01((x - a) / (b - a))
        return t * t * (3 - 2 * t)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Moves `value` towards `target` at most `rate × dt`.
    static func approach(_ value: CGFloat, _ target: CGFloat, rate: CGFloat, dt: CGFloat) -> CGFloat {
        let step = rate * max(dt, 0)
        if value < target { return min(value + step, target) }
        return max(value - step, target)
    }
}

/// xorshift64 for cosmetic randomness (never the simulation's `SeededRandom`).
struct BogRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// 0 ..< 1
    mutating func unit() -> CGFloat {
        CGFloat(Double(next() >> 11) / 9_007_199_254_740_992.0)
    }

    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }

    mutating func sign() -> CGFloat { unit() < 0.5 ? -1 : 1 }

    /// A stateless 0 ..< 1 hash of an index (stable per-item phases).
    static func hash(_ i: Int, _ salt: UInt64) -> CGFloat {
        var z = UInt64(bitPattern: Int64(i)) &+ (salt &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return CGFloat(Double(z >> 11) / 9_007_199_254_740_992.0)
    }
}

/// CoreGraphics painting in a y-up context (points). Every texture in the scene is drawn with these.
enum BogPainter {
    /// Renders `draw` into a fresh bitmap (y up, origin bottom-left, in points × `scale`). Pure CoreGraphics: no
    /// UIKit renderer, no actor isolation.
    static func image(width: CGFloat, height: CGFloat, scale: CGFloat,
                      draw: (CGContext, CGSize) -> Void) -> CGImage? {
        let size = CGSize(width: max(width, 1), height: max(height, 1))
        let k = max(scale, 0.25)
        let pw = max(Int((size.width * k).rounded(.up)), 1)
        let ph = max(Int((size.height * k).rounded(.up)), 1)
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: k, y: k)
        draw(ctx, size)
        return ctx.makeImage()
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, _ alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setFillColor(BogPaint.cg(c, alpha))
        ctx.fillPath()
    }

    static func fillEvenOdd(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, _ alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setFillColor(BogPaint.cg(c, alpha))
        ctx.fillPath(using: .evenOdd)
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, width: CGFloat, _ alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setStrokeColor(BogPaint.cg(c, alpha))
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    /// Fills `path` with a linear gradient from `a` to `b`.
    static func gradient(_ ctx: CGContext, _ path: CGPath, _ colors: [RGBA], _ locations: [CGFloat],
                         from a: CGPoint, to b: CGPoint) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        linear(ctx, colors, locations, from: a, to: b)
        ctx.restoreGState()
    }

    /// Fills `path` with a radial gradient about `center`.
    static func radialFill(_ ctx: CGContext, _ path: CGPath, _ colors: [RGBA], _ locations: [CGFloat],
                           center: CGPoint, radius: CGFloat) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        radial(ctx, colors, locations, center: center, radius: radius, extend: true)
        ctx.restoreGState()
    }

    static func linear(_ ctx: CGContext, _ colors: [RGBA], _ locations: [CGFloat], from a: CGPoint, to b: CGPoint) {
        guard colors.count >= 2, colors.count == locations.count else { return }
        let cg = colors.map { BogPaint.cg($0) } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: locations) else {
            return
        }
        ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radial(_ ctx: CGContext, _ colors: [RGBA], _ locations: [CGFloat], center: CGPoint, radius: CGFloat,
                       extend: Bool = false) {
        guard radius > 0, colors.count >= 2, colors.count == locations.count else { return }
        let cg = colors.map { BogPaint.cg($0) } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: locations) else {
            return
        }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                               options: extend ? [.drawsAfterEndLocation] : [])
    }

    /// A radial gradient squashed into an ellipse (semi-axes `rx`, `ry`) about `center`.
    static func ellipticalRadial(_ ctx: CGContext, _ colors: [RGBA], _ locations: [CGFloat], center: CGPoint,
                                 rx: CGFloat, ry: CGFloat, extend: Bool = false) {
        guard rx > 0, ry > 0 else { return }
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: 1, y: ry / rx)
        radial(ctx, colors, locations, center: .zero, radius: rx, extend: extend)
        ctx.restoreGState()
    }

    static func rect(_ r: CGRect) -> CGPath { CGPath(rect: r, transform: nil) }

    static func roundRect(_ r: CGRect, _ corner: CGFloat) -> CGPath {
        let c = max(min(corner, min(r.width, r.height) / 2), 0)
        return CGPath(roundedRect: r, cornerWidth: c, cornerHeight: c, transform: nil)
    }

    static func oval(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        oval(CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: rotation)
        p.addEllipse(in: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: t)
        return p
    }

    static func polygon(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }

    /// A glossy dew drop: a dark rim below, a clear body, a bright highlight (y up).
    static func dewDrop(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, tint: RGBA) {
        let body = circle(c, r)
        fill(ctx, circle(CGPoint(x: c.x + r * 0.15, y: c.y - r * 0.3), r * 1.05), RGBA(0, 0, 0), 0.22)
        radialFill(ctx, body, [BogPaint.lighter(tint, 0.65), BogPaint.alpha(tint, 0.55), BogPaint.darker(tint, 0.35)],
                   [0, 0.6, 1], center: CGPoint(x: c.x - r * 0.25, y: c.y + r * 0.3), radius: r * 1.4)
        stroke(ctx, body, BogPaint.darker(tint, 0.55), width: max(r * 0.16, 0.6), 0.55)
        fill(ctx, ellipse(CGPoint(x: c.x - r * 0.32, y: c.y + r * 0.36), r * 0.32, r * 0.2, rotation: 0.6),
             RGBA(1, 1, 1), 0.95)
        fill(ctx, circle(CGPoint(x: c.x + r * 0.38, y: c.y - r * 0.38), r * 0.12), RGBA(1, 1, 1), 0.55)
    }
}
