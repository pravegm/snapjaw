// Snapjaw App Store frame compositor (macOS host side). ci/store-set.sh compiles it with `xcrun swiftc` (falling back
// to `xcrun swift` as a script). It draws one landscape store frame from one raw simulator capture, in the caption
// system of docs/appstore/screenshots.md. Ported from the sister book-pose game's compositor (it drew every frame that
// game shipped with), recoloured for the bog and given Snapjaw's glossary:
//
//   store-frame --in raw.png --out frame.png --size 2868x1320 --caption "Never eat a *bee* / Bees cost snaps. Wait them out."
//               [--radius 0.06] [--layout auto|top|side]
//   store-frame --in duo-inner.png --out frame.png --size 2622x1206 --caption "…" --book [--angle 140] [--fold 1428]
//               [--tilt 15] [--yaw 0 (top) | -5 (side)] [--distance 2.8]
//
// Layout (Snapjaw is landscape: every slot is wider than tall).
//  • top (the default for flat frames): the caption band runs across the top (3.5–21.5 % of the height) and the capture
//    sits under it, as large as fits (24–96.5 %). A landscape headline of ≤ 7 words fits on one line at a size that
//    still reads in a search-results thumbnail, the eye reads caption-then-picture top to bottom, and the screenshot
//    keeps ~55 % of the frame (a side column would leave it ~44 %) without covering either lobe of the trap.
//  • side (auto for a --book frame on a slot wider than 1.8 : 1, i.e. the iPhone 6.9" and 6.3" slots): the caption is
//    a left-aligned column on the left third, the book on the right. An open book is only ~1.25 : 1, so under a top
//    band it would fill under half the width of a 2.2 : 1 iPhone frame.
// Look (docs/appstore/screenshots.md "Caption style", Snap/UI/SnapTheme.swift): a diagonal sweep from deep bog green
// #0E2A1B to moss #1F4A2C, a soft lime glow #9BCB3C behind the capture and a faint crimson #D62A4E ember (the trap's
// own colour) in the far top corner, both added with plus-lighter blending (normal blending at partial alpha over the
// green turns muddy), and a darker band along the bottom. Headline: SF Pro Rounded Heavy (plain system Heavy if the
// rounded design is missing) in dew white #F4FBEF, cap height from 6 % of the height (top) or 8.5 % (side), shrinking
// in 5 % steps (floor 4 % / 5 %) until it fits in ≤ 2 (top) or ≤ 3 (side) balanced lines. `*word*` is the ONE
// highlight: bog-ink #10261A letters on a nectar-gold #F2B632 marker swash. " / " starts the sub-line, SF Pro Rounded
// Semibold in mist green #B9D7B0 at ~46 % (top: shrinks to stay on one line, floor 36 %).
//
// Flat frames: the capture itself, unaltered, scaled to fit, with rounded corners (--radius × its shorter side), a
//   hairline edge and a soft shadow. No device is drawn.
// --book: the capture must be a real iPhone Duo inner-display frame (2853 × 2007, fold at x ≈ 1368–1488 px: the app's
//   "SNAP-T fold active 456,0 40x669" at 3x). It is split at the fold (--fold px, default 1428 at 2853 wide) and each
//   half is mapped, by a true perspective transform (Core Image CIPerspectiveTransform; the corner order is self-tested
//   at start-up), onto one page of a stylised iPhone Duo standing open like a book at --angle degrees (default 140;
//   each page turned (180 − angle) / 2 toward the viewer), tilted back --tilt degrees (default 15) and seen from in
//   front and above, from --distance page heights (default 2.8), turned --yaw degrees on a side layout (default −5). The two pages are the trap's two lobes and the hinge is its midrib. Drawn around it: a thin graphite bezel
//   (2.4 % of the page height, lit from the --light side), the hinge spine (a metal barrel showing past the top and
//   bottom bezel, and the seam in the bezel), a soft drop shadow and a ground shadow. No hands. Nothing is drawn ON
//   the screen: the pixels are the capture's, only warped; its outer corners are clipped to the display's rounded
//   corners.
// --light right|left (default right): the side the light comes from. It falls on the HUD's page, the sharp half: the
//   right one by default (a fold started from flat blurs the left half for ~2 s, so the HUD lives on the right).
//   ci/store-set.sh passes `left` only when the capture's log says `hudLeft=1`. That side gets the moss end of the
//   sweep, the lime glow's lean and the lit bezel page. The book geometry is the same either way: the capture is split
//   at the fold and each half stays on its own page.
// Caption glossary (CLAUDE.md bar 3, docs/appstore/screenshots.md, achievements.md "Copy rules"): a caption using
//   "smash", "squish", "squash", "splat", "kill", "slam", "Fold to …" or the free competitor's name ("Fold Smasher") is
//   REJECTED: no frame is written, exit status 2, `store-frame: caption rejected: …`. (ci/store-set.sh flags the softer
//   words: flat, "shut" on its own, quick, fast, free, prices.)
// Output: exactly --size pixels (default: the input's size), opaque sRGB PNG with no alpha channel.
// Prints one line: `store-frame: <out> <W>x<H> mode=flat|book layout=top|side cap=<% of H> lines=<n> font=<name>
//   rounded=<yes|no>` plus, for --book, ` angle=<a> fold=<px> warp=<ok|flipV|flipH|flipHV> extent=<ok|mismatch>`.
import AppKit
import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("store-frame: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: Arguments (`--key value`; a key followed by another `--key`, or by nothing, is a flag set to "1")

var options: [String: String] = [:]
var argv = Array(CommandLine.arguments.dropFirst())
while !argv.isEmpty {
    let key = argv.removeFirst()
    guard key.hasPrefix("--"), key.count > 2 else { fail("bad argument \(key)") }
    let name = String(key.dropFirst(2))
    if let next = argv.first, !next.hasPrefix("--") {
        options[name] = argv.removeFirst()
    } else {
        options[name] = "1"
    }
}
guard let input = options["in"], let output = options["out"] else { fail("needs --in and --out") }
let rawCaption = options["caption"] ?? ""
let bookMode = (options["book"] ?? "0") != "0"
let cornerFraction = CGFloat(Double(options["radius"] ?? "") ?? 0.06)

let lightLeft = (options["light"] ?? "right").lowercased() == "left"

// MARK: Caption glossary (the app's own words only; checked before anything is drawn)

func captionProblems(_ caption: String) -> [String] {
    let plain = caption.replacingOccurrences(of: "*", with: "")
    let rules: [(pattern: String, label: String)] = [
        // CLAUDE.md bar 3: choosing, not smashing. The free competitor smashes bugs; Snapjaw never says it does.
        ("\\bsmash(es|ed|ing|er|ers)?\\b", "\"smash\" (CLAUDE.md bar 3)"),
        ("\\bfold\\s*smasher\\b", "the competitor's name (Fold Smasher)"),
        ("\\bfold to\\b", "\"Fold to …\" (CLAUDE.md bar 3)"),
        // achievements.md "Copy rules" and screenshots.md: the bite is a gulp, never a squash; nothing about force.
        ("\\bsquish(es|ed|ing|y)?\\b", "\"squish\""),
        ("\\bsquash(es|ed|ing)?\\b", "\"squash\""),
        ("\\bsplat(s|ted|ting)?\\b", "\"splat\""),
        ("\\bkill(s|ed|ing|er)?\\b", "\"kill\""),
        ("\\bslam(s|med|ming)?\\b", "\"slam\""),
    ]
    var found: [String] = []
    let range = NSRange(plain.startIndex..., in: plain)
    for rule in rules {
        guard let re = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else { continue }
        if re.firstMatch(in: plain, options: [], range: range) != nil { found.append(rule.label) }
    }
    return found
}

let rejected = captionProblems(rawCaption)
if !rejected.isEmpty {
    let message = "store-frame: caption rejected: uses " + rejected.joined(separator: ", ")
        + " (glossary, docs/appstore/screenshots.md); no frame written"
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    print(message)
    exit(2)
}

func number(_ key: String, _ fallback: Double) -> Double {
    guard let text = options[key], let value = Double(text), value.isFinite else { return fallback }
    return value
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil),
      let shot = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("cannot read \(input)") }

var width = shot.width, height = shot.height
if let size = options["size"], !size.isEmpty, size != "raw" {
    let parts = size.lowercased().split(separator: "x").compactMap { Int($0) }
    guard parts.count == 2, parts[0] > 64, parts[1] > 64 else { fail("bad --size \(size)") }
    width = parts[0]
    height = parts[1]
}
let W = CGFloat(width), H = CGFloat(height)

guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { fail("no sRGB colour space") }
// noneSkipLast: an opaque RGB bitmap, so the PNG has no alpha channel (App Store Connect rejects alpha).
guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("no context") }
let ctx: CGContext = context
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)

func srgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Brand palette (docs/appstore/screenshots.md "Caption style", Snap/UI/SnapTheme.swift; sRGB).
let bogNight: UInt32 = 0x081C11      // the sweep's deepest corner (between SnapTheme night and bogDeep)
let bogGreen: UInt32 = 0x0E2A1B      // deep bog green
let moss: UInt32 = 0x1F4A2C          // moss, the light's end of the sweep
let limeGlow: UInt32 = 0x9BCB3C      // the soft lime glow behind the capture
let crimson: UInt32 = 0xD62A4E       // SnapTheme crimson: the trap's interior, a faint ember in the far corner
let dew: UInt32 = 0xF4FBEF           // headline: dew white
let mistGreen: UInt32 = 0xB9D7B0     // sub-line: mist green
let bogInk: UInt32 = 0x10261A        // letters on the gold swash
let nectarGold: UInt32 = 0xF2B632    // the nectar-gold marker swash
let shadowInk: UInt32 = 0x020805     // legibility / drop shadows (SnapTheme shadow)
let bezelDark: UInt32 = 0x16191B     // graphite: the page turned from the light
let bezelLit: UInt32 = 0x24292C      // graphite: the page facing the light

/// A top-left-origin rect → Core Graphics' bottom-left origin.
func cg(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height) }

enum Layout: String { case top, side }
let layout: Layout = {
    switch (options["layout"] ?? "auto").lowercased() {
    case "top": return .top
    case "side": return .side
    default: return (bookMode && W / H > 1.8) ? .side : .top
    }
}()

// Top-left-origin boxes for the caption and the picture.
let band: CGRect = layout == .top
    ? CGRect(x: W * 0.05, y: H * 0.035, width: W * 0.90, height: H * 0.18)
    : CGRect(x: W * 0.055, y: H * 0.12, width: W * 0.32, height: H * 0.76)
let pictureBox: CGRect = layout == .top
    ? CGRect(x: W * 0.04, y: H * 0.24, width: W * 0.92, height: H * 0.725)
    : CGRect(x: W * 0.40, y: H * 0.05, width: W * 0.57, height: H * 0.90)

// MARK: Background

ctx.setFillColor(srgb(bogGreen))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
if let sweep = CGGradient(colorsSpace: space,
                          colors: [srgb(bogNight), srgb(bogGreen), srgb(moss)] as CFArray,
                          locations: [0, 0.40, 1]) {
    // From the deep bog (bottom, away from the light) to moss (top, on the light's side).
    ctx.drawLinearGradient(sweep, start: CGPoint(x: lightLeft ? W : 0, y: 0), end: CGPoint(x: lightLeft ? 0 : W, y: H),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
ctx.saveGState()
ctx.setBlendMode(.plusLighter)   // additive light: lime or crimson at partial alpha over the green would turn muddy
if let glow = CGGradient(colorsSpace: space, colors: [srgb(limeGlow, 0.16), srgb(limeGlow, 0)] as CFArray,
                         locations: [0, 1]) {
    // Behind the capture (screenshots.md), leaning a little toward the light.
    let pic = cg(pictureBox)
    let centre = CGPoint(x: pic.midX + W * (lightLeft ? -0.06 : 0.06), y: pic.midY)
    ctx.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre,
                           endRadius: max(W, H) * 0.45, options: [])
}
if let ember = CGGradient(colorsSpace: space, colors: [srgb(crimson, 0.09), srgb(crimson, 0)] as CFArray,
                          locations: [0, 1]) {
    // A faint crimson ember in the top corner away from the light: the trap's colour, kept off the caption's middle.
    let centre = CGPoint(x: lightLeft ? W * 0.96 : W * 0.04, y: H * 0.96)
    ctx.drawRadialGradient(ember, startCenter: centre, startRadius: 0, endCenter: centre,
                           endRadius: max(W, H) * 0.32, options: [])
}
ctx.restoreGState()
if let floor = CGGradient(colorsSpace: space, colors: [srgb(shadowInk, 0.40), srgb(shadowInk, 0)] as CFArray,
                          locations: [0, 1]) {
    // The darker band along the bottom (screenshots.md).
    ctx.drawLinearGradient(floor, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: H * 0.30), options: [])
}

// MARK: Flat frame (the capture, unaltered, scaled to fit the picture box)

func drawFlat() {
    let fit = min(pictureBox.width / CGFloat(shot.width), pictureBox.height / CGFloat(shot.height))
    let shotW = (CGFloat(shot.width) * fit).rounded()
    let shotH = (CGFloat(shot.height) * fit).rounded()
    let shotRect = CGRect(x: (pictureBox.midX - shotW / 2).rounded(), y: (pictureBox.midY - shotH / 2).rounded(),
                          width: shotW, height: shotH)   // top-left origin
    let radius = max(0, min(min(shotW, shotH) * cornerFraction, shotW * 0.49, shotH * 0.49))
    let shotPath = CGPath(roundedRect: cg(shotRect), cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -H * 0.010), blur: H * 0.040, color: srgb(0x000000, 0.50))
    ctx.addPath(shotPath)
    ctx.setFillColor(srgb(shadowInk))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shotPath)
    ctx.clip()
    ctx.draw(shot, in: cg(shotRect))
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shotPath)
    ctx.setStrokeColor(srgb(dew, 0.16))
    ctx.setLineWidth(max(1, H * 0.0015))
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: Book frame (a Duo inner capture on a stylised iPhone Duo held open like a book)

/// Core Image renders the perspective warps. A paravirtual GPU can refuse, so a software context is the fallback.
var ciContext = CIContext(options: [CIContextOption.outputColorSpace: space])
var usedSoftwareCI = false

func render(_ image: CIImage, _ rect: CGRect) -> CGImage? {
    if let out = ciContext.createCGImage(image, from: rect) { return out }
    if usedSoftwareCI { return nil }
    usedSoftwareCI = true
    ciContext = CIContext(options: [CIContextOption.outputColorSpace: space, CIContextOption.useSoftwareRenderer: true])
    return ciContext.createCGImage(image, from: rect)
}

/// Warps `image` so its top-left / top-right / bottom-left / bottom-right corners land on the given points
/// (bottom-left-origin pixel coordinates of the output). Returns the rendered image and where to draw it.
func warp(_ image: CGImage, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) -> (image: CGImage, rect: CGRect)? {
    guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: tl), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: tr), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: bl), forKey: "inputBottomLeft")
    filter.setValue(CIVector(cgPoint: br), forKey: "inputBottomRight")
    guard let out = filter.outputImage else { return nil }
    let rect = out.extent.integral
    guard rect.width >= 1, rect.height >= 1, rect.width < 40000, rect.height < 40000,
          let rendered = render(out, rect) else { return nil }
    return (rendered, rect)
}

/// RGB of one pixel (x from the left, y from the top) of a CGImage.
func pixel(_ image: CGImage, _ x: Int, _ yFromTop: Int) -> (r: Int, g: Int, b: Int)? {
    guard let probe = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    probe.interpolationQuality = .none
    probe.setFillColor(srgb(0x000000))
    probe.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    probe.draw(image, in: CGRect(x: -CGFloat(x), y: -CGFloat(image.height - 1 - yFromTop),
                                 width: CGFloat(image.width), height: CGFloat(image.height)))
    guard let data = probe.data else { return nil }
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
}

/// Self-test of the warp's corner convention: a four-colour test card (red top-left, green top-right, blue
/// bottom-left, white bottom-right) is warped onto an upright square and read back. Returns which flips the real warps
/// need, or nil if Core Image can't warp at all.
func warpConvention() -> (flipV: Bool, flipH: Bool)? {
    guard let card = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    card.setFillColor(srgb(0xFF0000)); card.fill(CGRect(x: 0, y: 4, width: 4, height: 4))   // top-left
    card.setFillColor(srgb(0x00FF00)); card.fill(CGRect(x: 4, y: 4, width: 4, height: 4))   // top-right
    card.setFillColor(srgb(0x0000FF)); card.fill(CGRect(x: 0, y: 0, width: 4, height: 4))   // bottom-left
    card.setFillColor(srgb(0xFFFFFF)); card.fill(CGRect(x: 4, y: 0, width: 4, height: 4))   // bottom-right
    guard let image = card.makeImage(),
          let done = warp(image, tl: CGPoint(x: 0, y: 80), tr: CGPoint(x: 80, y: 80),
                          bl: CGPoint(x: 0, y: 0), br: CGPoint(x: 80, y: 0)) else { return nil }
    // Sample the centre of the output's top-left quadrant (in the output image's own pixels).
    let qx = max(0, min(done.image.width - 1, done.image.width / 4))
    let qy = max(0, min(done.image.height - 1, done.image.height / 4))
    guard let p = pixel(done.image, qx, qy) else { return nil }
    func near(_ r: Int, _ g: Int, _ b: Int) -> Bool { abs(p.r - r) < 90 && abs(p.g - g) < 90 && abs(p.b - b) < 90 }
    if near(255, 0, 0) { return (false, false) }
    if near(0, 0, 255) { return (true, false) }
    if near(0, 255, 0) { return (false, true) }
    if near(255, 255, 255) { return (true, true) }
    return nil
}

struct P3 { var x: Double; var y: Double; var z: Double }

/// The axis-aligned box around some points.
func bounds(_ points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .zero }
    var lo = first, hi = first
    for p in points {
        lo.x = min(lo.x, p.x); lo.y = min(lo.y, p.y)
        hi.x = max(hi.x, p.x); hi.y = max(hi.y, p.y)
    }
    return CGRect(x: lo.x, y: lo.y, width: hi.x - lo.x, height: hi.y - lo.y)
}

var bookReport = ""

func drawBook() {
    let iw = shot.width, ih = shot.height
    let aspect = Double(iw) / Double(ih)
    if aspect < 1.2 || aspect > 1.7 {
        FileHandle.standardError.write("store-frame: warning: --book source is \(iw)x\(ih), not a Duo inner capture\n"
            .data(using: .utf8)!)
    }
    var fold = Int((Double(iw) * 1428.0 / 2853.0).rounded())
    if let text = options["fold"], let f = Int(text) { fold = f }
    fold = max(1, min(iw - 1, fold))
    let wl = Double(fold), wr = Double(iw - fold), h = Double(ih)
    let angle = max(100, min(175, number("angle", 140)))
    let theta = (180 - angle) / 2 * Double.pi / 180      // each page turned this far toward the viewer
    // R7 (SCORE-R6 #6): the fold must read at search-thumbnail size. At tilt 8 and a far camera a 146° book showed a
    // V only along its top edge and read as ~170°. Seen from higher (tilt 15) and a little closer (2.8 h), both the
    // top and the bottom edge bow toward the spine and the outer edges stand ~9 % taller than the spine; on a side
    // layout (the iPhone slots: the book on the right of the caption) the book also turns 5° toward the caption, so
    // one page is visibly nearer than the other (store-banner.swift's side default).
    let tilt = max(-30, min(30, number("tilt", 15))) * Double.pi / 180
    let yaw = max(-30, min(30, number("yaw", layout == .top ? 0 : -5))) * Double.pi / 180
    let bezel = h * 0.024
    let deviceRadius = h * 0.065
    let screenRadius = max(0, deviceRadius - bezel)
    let distance = h * max(2.2, min(5, number("distance", 2.8)))   // camera distance from the spine (× page height)
    let eye = h * 0.06

    guard let convention = warpConvention() else { fail("Core Image perspective warp unavailable") }

    /// A point on one page: side −1 = left page, +1 = right; u from the spine outward along the page, v up.
    func page(_ side: Double, _ u: Double, _ v: Double) -> P3 {
        P3(x: side * u * cos(theta), y: v, z: u * sin(theta))
    }
    /// Tilt the book back (top away), turn it by the yaw, then project from a camera on the +z axis.
    func project(_ p: P3) -> CGPoint {
        let y1 = p.y * cos(tilt) + p.z * sin(tilt)
        let z1 = -p.y * sin(tilt) + p.z * cos(tilt)
        let x2 = p.x * cos(yaw) + z1 * sin(yaw)
        let z2 = -p.x * sin(yaw) + z1 * cos(yaw)
        let k = distance / max(distance - z2, 1)
        return CGPoint(x: x2 * k, y: (y1 - eye) * k)
    }
    /// A page outline in (u, v): square at the spine, rounded at the two outer corners.
    func outline(_ uMax: Double, _ vHalf: Double, _ r: Double) -> [(Double, Double)] {
        var pts: [(Double, Double)] = [(0, vHalf)]
        let n = 12
        for i in 0...n {
            let a = Double.pi / 2 - Double(i) / Double(n) * Double.pi / 2
            pts.append((uMax - r + r * cos(a), vHalf - r + r * sin(a)))
        }
        for i in 0...n {
            let a = -Double(i) / Double(n) * Double.pi / 2
            pts.append((uMax - r + r * cos(a), -vHalf + r + r * sin(a)))
        }
        pts.append((0, -vHalf))
        return pts
    }

    let spineHalf = bezel * 1.1
    let spineReach = h / 2 + bezel * 1.35
    let spineDepth = bezel * 0.8
    let spineWorld = [P3(x: -spineHalf, y: spineReach, z: -spineDepth), P3(x: spineHalf, y: spineReach, z: -spineDepth),
                      P3(x: spineHalf, y: -spineReach, z: -spineDepth), P3(x: -spineHalf, y: -spineReach, z: -spineDepth)]
    let leftBody = outline(wl + bezel, h / 2 + bezel, deviceRadius)
    let rightBody = outline(wr + bezel, h / 2 + bezel, deviceRadius)

    // Fit the projected device into the picture box (a little headroom below for the ground shadow).
    var raw: [CGPoint] = spineWorld.map(project)
    raw += leftBody.map { project(page(-1, $0.0, $0.1)) }
    raw += rightBody.map { project(page(1, $0.0, $0.1)) }
    let minX = raw.map(\.x).min() ?? 0, maxX = raw.map(\.x).max() ?? 1
    let minY = raw.map(\.y).min() ?? 0, maxY = raw.map(\.y).max() ?? 1
    let box = cg(pictureBox)
    let fitBox = CGRect(x: box.minX, y: box.minY + box.height * 0.06, width: box.width, height: box.height * 0.92)
    let scale = min(fitBox.width / max(maxX - minX, 1), fitBox.height / max(maxY - minY, 1))
    let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
    func place(_ q: CGPoint) -> CGPoint {
        CGPoint(x: fitBox.midX + (q.x - midX) * scale, y: fitBox.midY + (q.y - midY) * scale)
    }
    func at(_ side: Double, _ u: Double, _ v: Double) -> CGPoint { place(project(page(side, u, v))) }
    func path(_ side: Double, _ pts: [(Double, Double)]) -> CGPath {
        let p = CGMutablePath()
        for (i, q) in pts.enumerated() {
            if i == 0 { p.move(to: at(side, q.0, q.1)) } else { p.addLine(to: at(side, q.0, q.1)) }
        }
        p.closeSubpath()
        return p
    }
    let leftBodyPath = path(-1, leftBody)
    let rightBodyPath = path(1, rightBody)
    let leftScreenPath = path(-1, outline(wl, h / 2, screenRadius))
    let rightScreenPath = path(1, outline(wr, h / 2, screenRadius))
    let deviceBounds = leftBodyPath.boundingBox.union(rightBodyPath.boundingBox)

    // Ground shadow: a soft ellipse under the book.
    if let ground = CGGradient(colorsSpace: space, colors: [srgb(0x000000, 0.50), srgb(0x000000, 0)] as CFArray,
                               locations: [0, 1]) {
        ctx.saveGState()
        ctx.translateBy(x: deviceBounds.midX, y: deviceBounds.minY + deviceBounds.height * 0.01)
        ctx.scaleBy(x: deviceBounds.width * 0.50, y: deviceBounds.height * 0.07)
        ctx.drawRadialGradient(ground, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
        ctx.restoreGState()
    }

    // The hinge spine: a metal barrel behind the crease, showing past the top and bottom bezels.
    let spineRect = bounds(spineWorld.map { place(project($0)) })
    let spineCorner = max(0, min(spineRect.width * 0.49, spineRect.height * 0.49))
    let spinePath = CGPath(roundedRect: spineRect, cornerWidth: spineCorner, cornerHeight: spineCorner, transform: nil)
    if let metal = CGGradient(colorsSpace: space,
                              colors: [srgb(0x0C1018), srgb(0x5A6474), srgb(0x2A3240), srgb(0x0C1018)] as CFArray,
                              locations: [0, 0.38, 0.62, 1]) {
        ctx.saveGState()
        ctx.addPath(spinePath)
        ctx.clip()
        ctx.drawLinearGradient(metal, start: CGPoint(x: spineRect.minX, y: spineRect.midY),
                               end: CGPoint(x: spineRect.maxX, y: spineRect.midY), options: [])
        ctx.restoreGState()
    }

    // The body: one soft drop shadow for both pages, then each page's bezel (the right page faces the light).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -H * 0.012), blur: H * 0.045, color: srgb(0x000000, 0.55))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(leftBodyPath)
    ctx.addPath(rightBodyPath)
    ctx.setFillColor(srgb(bezelDark))
    ctx.fillPath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    for (bodyPath, colour) in [(leftBodyPath, lightLeft ? bezelLit : bezelDark),
                               (rightBodyPath, lightLeft ? bezelDark : bezelLit)] {
        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.setFillColor(srgb(colour))
        ctx.fillPath()
        ctx.addPath(bodyPath)
        ctx.setStrokeColor(srgb(0xFFFFFF, 0.12))
        ctx.setLineWidth(max(1, H * 0.0016))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // The screens: each half of the capture, only warped (true perspective), clipped to the display's outline.
    guard let leftHalf = shot.cropping(to: CGRect(x: 0, y: 0, width: fold, height: ih)),
          let rightHalf = shot.cropping(to: CGRect(x: fold, y: 0, width: iw - fold, height: ih)) else {
        fail("cannot split the capture at x=\(fold)")
    }
    var extentOK = true
    func drawHalf(_ half: CGImage, _ clip: CGPath, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) {
        var c = (tl: tl, tr: tr, bl: bl, br: br)
        if convention.flipV { c = (tl: c.bl, tr: c.br, bl: c.tl, br: c.tr) }
        if convention.flipH { c = (tl: c.tr, tr: c.tl, bl: c.br, br: c.bl) }
        guard let done = warp(half, tl: c.tl, tr: c.tr, bl: c.bl, br: c.br) else { fail("perspective warp failed") }
        let expected = bounds([tl, tr, bl, br])
        if abs(done.rect.minX - expected.minX) > 4 || abs(done.rect.maxX - expected.maxX) > 4
            || abs(done.rect.minY - expected.minY) > 4 || abs(done.rect.maxY - expected.maxY) > 4 {
            extentOK = false
        }
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        ctx.setFillColor(srgb(0x000000))      // the panel is black glass behind the picture
        ctx.fill(clip.boundingBox)
        ctx.draw(done.image, in: done.rect)
        ctx.restoreGState()
    }
    // Left half: its left edge (x = 0) is the outer edge, its right edge is the spine.
    drawHalf(leftHalf, leftScreenPath, tl: at(-1, wl, h / 2), tr: at(-1, 0, h / 2),
             bl: at(-1, wl, -h / 2), br: at(-1, 0, -h / 2))
    drawHalf(rightHalf, rightScreenPath, tl: at(1, 0, h / 2), tr: at(1, wr, h / 2),
             bl: at(1, 0, -h / 2), br: at(1, wr, -h / 2))

    // The hinge seam through the top and bottom bezel (never over the screen).
    ctx.saveGState()
    ctx.setStrokeColor(srgb(0x000000, 0.70))
    ctx.setLineWidth(max(1, H * 0.0018))
    ctx.move(to: at(1, 0, h / 2)); ctx.addLine(to: at(1, 0, h / 2 + bezel))
    ctx.move(to: at(1, 0, -h / 2)); ctx.addLine(to: at(1, 0, -h / 2 - bezel))
    ctx.strokePath()
    ctx.restoreGState()

    let flips = (convention.flipV ? "V" : "") + (convention.flipH ? "H" : "")
    bookReport = " angle=\(Int(angle.rounded())) fold=\(fold) warp=\(flips.isEmpty ? "ok" : "flip" + flips)"
        + " extent=\(extentOK ? "ok" : "mismatch")" + (usedSoftwareCI ? " ci=software" : "")
        + " light=\(lightLeft ? "left" : "right")"
}

if bookMode { drawBook() } else { drawFlat() }

// MARK: Caption (Core Text, laid out top-down, drawn in Core Graphics coordinates)

struct Seg { var text: String; var hi: Bool }
typealias Token = [Seg]          // one unbreakable word (a `*highlighted phrase*` stays in one token)
typealias Words = [Token]

/// Splits on spaces outside `*…*`; `*` toggles the highlight and is never drawn.
func tokenize(_ text: String) -> Words {
    var tokens: Words = []
    var current: Token = []
    var buffer = ""
    var hi = false
    func flushSeg() {
        if !buffer.isEmpty { current.append(Seg(text: buffer, hi: hi)); buffer = "" }
    }
    for ch in text {
        if ch == "*" { flushSeg(); hi.toggle(); continue }
        if ch == " " && !hi {
            flushSeg()
            if !current.isEmpty { tokens.append(current); current = [] }
            continue
        }
        buffer.append(ch)
    }
    flushSeg()
    if !current.isEmpty { tokens.append(current) }
    return tokens
}

let fontKey = NSAttributedString.Key(rawValue: kCTFontAttributeName as String)
let colorKey = NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String)
let kernKey = NSAttributedString.Key(rawValue: kCTKernAttributeName as String)

struct Style { var font: CTFont; var color: CGColor; var hiColor: CGColor; var kern: CGFloat }

/// One line's attributed string and its highlighted UTF-16 ranges (highlighted letters in `hiColor`).
func attributed(_ words: Words, _ style: Style) -> (text: NSAttributedString, highlights: [NSRange]) {
    let result = NSMutableAttributedString()
    var highlights: [NSRange] = []
    let kern = NSNumber(value: Double(style.kern))
    let plain: [NSAttributedString.Key: Any] = [fontKey: style.font, colorKey: style.color, kernKey: kern]
    let lit: [NSAttributedString.Key: Any] = [fontKey: style.font, colorKey: style.hiColor, kernKey: kern]
    for (i, token) in words.enumerated() {
        if i > 0 { result.append(NSAttributedString(string: " ", attributes: plain)) }
        for seg in token {
            if seg.hi { highlights.append(NSRange(location: result.length, length: (seg.text as NSString).length)) }
            result.append(NSAttributedString(string: seg.text, attributes: seg.hi ? lit : plain))
        }
    }
    return (result, highlights)
}

func measure(_ words: Words, _ style: Style) -> CGFloat {
    let line = CTLineCreateWithAttributedString(attributed(words, style).text as CFAttributedString)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

func greedy(_ words: Words, _ limit: CGFloat, _ style: Style) -> [Words] {
    var lines: [Words] = []
    var current: Words = []
    for token in words {
        if current.isEmpty || measure(current + [token], style) <= limit {
            current.append(token)
        } else {
            lines.append(current)
            current = [token]
        }
    }
    if !current.isEmpty { lines.append(current) }
    return lines
}

/// As many lines as a greedy wrap needs, at the narrowest width that keeps that count (even lines, no orphan).
func balanced(_ words: Words, _ width: CGFloat, _ style: Style) -> [Words] {
    guard words.count > 1, measure(words, style) > width else { return [words] }
    let count = greedy(words, width, style).count
    var lo: CGFloat = 0
    var hi = width
    for _ in 0..<18 {
        let mid = (lo + hi) / 2
        if greedy(words, mid, style).count <= count { hi = mid } else { lo = mid }
    }
    return greedy(words, hi, style)
}

/// Balanced lines, preferring a break after a sentence (". ", "! ", "? ", ": ") when that costs no extra line.
func wrap(_ words: Words, _ width: CGFloat, _ style: Style, sentenceBreaks: Bool) -> [Words] {
    let plain = balanced(words, width, style)
    guard sentenceBreaks, plain.count > 1, words.count > 1 else { return plain }
    func widest(_ lines: [Words]) -> CGFloat { lines.map { measure($0, style) }.max() ?? 0 }
    var chosen = plain
    var chosenIsSentence = false
    for i in 0..<(words.count - 1) {
        guard let last = words[i].last?.text.last, ".!?:".contains(last) else { continue }
        let option = balanced(Array(words[...i]), width, style) + balanced(Array(words[(i + 1)...]), width, style)
        guard option.count <= plain.count else { continue }
        if !chosenIsSentence || widest(option) < widest(chosen) {
            chosen = option
            chosenIsSentence = true
        }
    }
    return chosen
}

struct Laid {
    var lines: [CTLine] = []
    var highlights: [[NSRange]] = []
    var widths: [CGFloat] = []
    var lineHeight: CGFloat = 0
    var ascentShare: CGFloat = 0.8
    var size: CGFloat = 0
    var capHeight: CGFloat = 0
    var height: CGFloat { lineHeight * CGFloat(lines.count) }
}

func lay(_ words: Words, _ style: Style, width: CGFloat, sentenceBreaks: Bool, leading: CGFloat) -> Laid {
    var laid = Laid()
    let ascent = CTFontGetAscent(style.font), descent = CTFontGetDescent(style.font)
    laid.lineHeight = (ascent + descent) * leading
    laid.ascentShare = ascent / max(ascent + descent, 1)
    laid.size = CTFontGetSize(style.font)
    laid.capHeight = CTFontGetCapHeight(style.font)
    for lineWords in wrap(words, width, style, sentenceBreaks: sentenceBreaks) {
        let (text, highlights) = attributed(lineWords, style)
        let line = CTLineCreateWithAttributedString(text as CFAttributedString)
        laid.lines.append(line)
        laid.highlights.append(highlights)
        laid.widths.append(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
    }
    return laid
}

var usedRounded = true
func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> CTFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = base.fontDescriptor.withDesign(.rounded),
       let font = NSFont(descriptor: descriptor, size: size) {
        return font as CTFont
    }
    usedRounded = false
    return base as CTFont
}

let capStart = layout == .top ? H * 0.060 : H * 0.085
let capFloor = layout == .top ? H * 0.040 : H * 0.050
let maxHeadLines = layout == .top ? 2 : 3
let centred = layout == .top

var reportCap: CGFloat = 0
var reportLines = 0
var reportFont = ""

func drawLaid(_ laid: Laid, top: CGFloat) {
    for (i, line) in laid.lines.enumerated() {
        let lineTop = top + CGFloat(i) * laid.lineHeight
        let baseline = lineTop + laid.lineHeight * laid.ascentShare     // top-left origin
        let x = centred ? band.midX - laid.widths[i] / 2 : band.minX
        let baseCG = H - baseline
        for range in laid.highlights[i] {
            // The marker swash: bog-ink letters on nectar gold, slightly tilted like a highlighter stroke.
            let x0 = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let x1 = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)
            let pad = laid.size * 0.10
            let swash = CGRect(x: x + x0 - pad, y: baseCG - laid.size * 0.15,
                               width: (x1 - x0) + pad * 2, height: laid.capHeight + laid.size * 0.30)
            ctx.saveGState()
            ctx.translateBy(x: swash.midX, y: swash.midY)
            ctx.rotate(by: 0.018)
            let local = CGRect(x: -swash.width / 2, y: -swash.height / 2, width: swash.width, height: swash.height)
            let corner = max(0, min(swash.height * 0.28, swash.width * 0.49, swash.height * 0.49))
            ctx.addPath(CGPath(roundedRect: local, cornerWidth: corner, cornerHeight: corner, transform: nil))
            ctx.setFillColor(srgb(nectarGold))
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: baseCG)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}

if !rawCaption.trimmingCharacters(in: .whitespaces).isEmpty {
    let parts = rawCaption.components(separatedBy: " / ")
    let headWords = tokenize(parts[0])
    let subText: String? = parts.count > 1 ? parts.dropFirst().joined(separator: " / ") : nil
    let subWords = subText.map { tokenize($0.replacingOccurrences(of: "*", with: "")) } ?? []

    let probe = roundedFont(100, .heavy)
    let capRatio = max(CTFontGetCapHeight(probe) / 100, 0.5)

    var cap = capStart
    var head = Laid()
    var sub: Laid? = nil
    var gap: CGFloat = 0
    while true {
        let size = cap / capRatio
        let headStyle = Style(font: roundedFont(size, .heavy), color: srgb(dew), hiColor: srgb(bogInk), kern: -0.008 * size)
        head = lay(headWords, headStyle, width: band.width, sentenceBreaks: true, leading: 0.92)
        sub = nil
        if !subWords.isEmpty {
            var subSize = size * 0.46
            if layout == .top {
                let natural = measure(subWords, Style(font: roundedFont(subSize, .semibold), color: srgb(mistGreen),
                                                      hiColor: srgb(mistGreen), kern: 0))
                let room = band.width * 0.97
                if natural > room { subSize = max(size * 0.36, subSize * room / max(natural, 1)) }
            }
            let subStyle = Style(font: roundedFont(subSize, .semibold), color: srgb(mistGreen), hiColor: srgb(mistGreen), kern: 0)
            sub = lay(subWords, subStyle, width: band.width, sentenceBreaks: layout == .side, leading: 1.05)
        }
        gap = sub == nil ? 0 : size * 0.32
        let total = head.height + gap + (sub?.height ?? 0)
        if (head.lines.count <= maxHeadLines && total <= band.height) || cap <= capFloor { break }
        cap = max(capFloor, cap * 0.95)
    }

    let total = head.height + gap + (sub?.height ?? 0)
    let top = max(band.minY, band.midY - total / 2)
    drawLaid(head, top: top)
    if let sub { drawLaid(sub, top: top + head.height + gap) }

    reportCap = cap
    reportLines = head.lines.count
    reportFont = CTFontCopyPostScriptName(roundedFont(10, .heavy)) as String
}

// MARK: Output (opaque sRGB PNG, no alpha)

guard let flat = ctx.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, "public.png" as CFString,
                                                        1, nil) else { fail("cannot create \(output)") }
CGImageDestinationAddImage(destination, flat, nil)
guard CGImageDestinationFinalize(destination) else { fail("cannot write \(output)") }
let capPercent = String(format: "%.1f", Double(reportCap / H * 100))
print("store-frame: \(output) \(width)x\(height) mode=\(bookMode ? "book" : "flat") layout=\(layout.rawValue) "
      + "cap=\(capPercent)% lines=\(reportLines) font=\(reportFont.isEmpty ? "-" : reportFont) "
      + "rounded=\(usedRounded ? "yes" : "no")" + bookReport)
