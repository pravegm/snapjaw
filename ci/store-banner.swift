// Snapjaw App Store creative-asset renderer (macOS host side; ci/store-placements.sh runs it, compiled with
// `xcrun swiftc` or as a script with `xcrun swift`). Draws the two optional placements Apple added on 5 Oct 2026 (the
// product page header and the search results art) from a REAL iPhone Duo inner-display capture (2853 x 2007, ci/duo.sh
// store pass). Ported from the sister book-pose game's renderer (its header and search art went live through it):
//
//   store-banner --kind header --hero store-D01-book-hero.png --out header-3840x1646.png [--light right] [--angle 146]
//   store-banner --kind search --hero store-D01-book-hero.png --out search-3840x2560.png
//                --caption "Your Duo is a *flytrap* / Hold it open like a book." [--layout top|side]
//                [--guides guides.png] [--yaw 0] [--tilt 8] [--device-box x0,y0,x1,y1] [--text-box x0,y0,x1,y1]
//
//  • The hero is the iPhone Duo held open like a book, exactly as ci/store-frame.swift draws screenshot frame 1 (the
//    same model, bezel, hinge spine and shadows): the capture is split at the fold (x = 1428 of 2853) and each half is
//    put on its own page by a true perspective transform (Core Image; the corner convention is self-tested first,
//    and each half is Lanczos-scaled to about its drawn size before the warp so fine lines don't alias). The two pages
//    are the trap's lobes, the hinge its midrib. The capture's pixels are only resampled; nothing is painted on the
//    screen. No hands, no logo, no buttons, no badge.
//  • Type and colour are ci/store-frame.swift's (docs/appstore/screenshots.md "Caption style"): the bog green → moss
//    sweep, the lime glow and a faint crimson ember added with plus-lighter, SF Pro Rounded Heavy headlines in dew
//    white with ONE `*word*` as bog-ink on the nectar-gold swash, the sub-line in Semibold mist green. The header's
//    wordmark is the app's own Home title (Snap/UI/HomeView.swift): "Snapjaw" in Rounded Black filled cream → light
//    lime with a hard crimson-deep shadow, and the tagline "Feed the flytrap. Spare bees." (AppBrand.tagline) under it.
//  • --light left|right (default right): the side the light comes from. It falls on the HUD's page (the sharp half, the
//    right by default), so ci/store-placements.sh passes `left` only when the capture's log says `hudLeft=1`, as
//    ci/store-set.sh does for the screenshots.
//  • Layouts: header (21:9): the wordmark in a column on the left, the book on the right. Search (3:2), `top` (the
//    default): one headline line and the sub-line across the top, the book big and centred under it, in the middle of
//    Apple's template safe area. `side`: a small wordmark, the headline (≤ 3 lines) and the sub-line in a left column,
//    the book on the right (kept as the review alternative).
//  • Captions go through the screenshot glossary (store-frame.swift): "smash", "squish", "squash", "splat", "kill",
//    "slam", "Fold to …" or the competitor's name → exit 2, nothing written.
//  • Output: exactly 3840 x 2560 (search) or 3840 x 1646 (header), opaque sRGB PNG, no alpha channel. --guides writes
//    a review copy with Apple's template safe area (red; header x 1097–2743 / y 493–1154, search x 836–3004 /
//    y 765–1795, as others measured them: Apple publishes no numbers) and what an iPhone shows (blue) drawn on.
// Prints one line: `store-banner: <out> <W>x<H> kind=… layout=… device=<rect> text=<rect> text-iphone=<yes|no>
// overlap=<yes|no> text-in-template-safe=<yes|no> device-centre-in-template-safe=<yes|no> rounded=<yes|no>
// angle=<a> fold=<px> warp=<ok|flip…> extent=<ok|mismatch> light=<left|right>` (rects in top-left pixels).
import AppKit
import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("store-banner: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: Arguments (`--key value`; a key followed by another `--key`, or by nothing, is a flag set to "1"; last wins)

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

let kind = (options["kind"] ?? "search").lowercased()
guard kind == "search" || kind == "header" else { fail("--kind is search or header") }
guard let heroPath = options["hero"], let output = options["out"] else { fail("needs --hero and --out") }
let layout: String = {
    if kind == "header" { return "side" }
    return (options["layout"] ?? "top").lowercased() == "side" ? "side" : "top"
}()
let lightLeft = (options["light"] ?? "right").lowercased() == "left"
let rawCaption = options["caption"] ?? ""

func number(_ key: String, _ fallback: Double) -> Double {
    guard let text = options[key], let value = Double(text), value.isFinite else { return fallback }
    return value
}
func num(_ key: String, _ fallback: CGFloat) -> CGFloat { CGFloat(number(key, Double(fallback))) }

// MARK: Caption glossary (ci/store-frame.swift's rules; checked before anything is drawn)

func captionProblems(_ caption: String) -> [String] {
    let plain = caption.replacingOccurrences(of: "*", with: "")
    let rules: [(pattern: String, label: String)] = [
        ("\\bsmash(es|ed|ing|er|ers)?\\b", "\"smash\" (CLAUDE.md bar 3)"),
        ("\\bfold\\s*smasher\\b", "the competitor's name (Fold Smasher)"),
        ("\\bfold to\\b", "\"Fold to …\" (CLAUDE.md bar 3)"),
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
    let message = "store-banner: caption rejected: uses " + rejected.joined(separator: ", ")
        + " (glossary, docs/appstore/screenshots.md); nothing written"
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    print(message)
    exit(2)
}

// MARK: The capture

guard let heroSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: heroPath) as CFURL, nil),
      let hero = CGImageSourceCreateImageAtIndex(heroSource, 0, nil) else { fail("cannot read \(heroPath)") }
guard hero.width == 2853, hero.height == 2007 else {
    fail("\(heroPath) is \(hero.width)x\(hero.height); the hero must be an iPhone Duo inner capture, 2853x2007")
}

let width = 3840
let height = kind == "search" ? 2560 : 1646
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

// Brand palette (docs/appstore/screenshots.md "Caption style", Snap/UI/SnapTheme.swift, ci/store-frame.swift; sRGB).
let bogNight: UInt32 = 0x081C11      // the sweep's deepest corner (between SnapTheme night and bogDeep)
let bogGreen: UInt32 = 0x0E2A1B      // deep bog green
let moss: UInt32 = 0x1F4A2C          // moss, the light's end of the sweep
let limeGlow: UInt32 = 0x9BCB3C      // the soft lime glow behind the device
let crimson: UInt32 = 0xD62A4E       // SnapTheme crimson: the trap's interior, a faint ember in the far corner
let dew: UInt32 = 0xF4FBEF           // headline: dew white
let mistGreen: UInt32 = 0xB9D7B0     // sub-line: mist green
let bogInk: UInt32 = 0x10261A        // letters on the gold swash
let nectarGold: UInt32 = 0xF2B632    // the nectar-gold marker swash
let cream: UInt32 = 0xFFF7E2         // SnapTheme cream: the wordmark's top, the tagline
let limeLight: UInt32 = 0xCDEE85     // SnapTheme limeLight: the wordmark's bottom
let crimsonDeep: UInt32 = 0x8A1232   // SnapTheme crimsonDeep: the wordmark's hard shadow
let shadowInk: UInt32 = 0x020805     // legibility / drop shadows (SnapTheme shadow)
let bezelDark: UInt32 = 0x16191B     // graphite: the page turned from the light
let bezelLit: UInt32 = 0x24292C      // graphite: the page facing the light

/// Top-left-origin rect / point → Core Graphics' bottom-left origin (and back: the same formula).
func cg(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height) }
func cgp(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: H - p.y) }
func toTL(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height) }

// MARK: Layout (top-left pixel coordinates, from fractions of the canvas)

func fractionBox(_ key: String, _ fallback: [CGFloat]) -> CGRect {
    var f = fallback
    if let text = options[key] {
        let parts = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 4, parts[2] > parts[0], parts[3] > parts[1] { f = parts.map { CGFloat($0) } }
    }
    return CGRect(x: W * f[0], y: H * f[1], width: W * (f[2] - f[0]), height: H * (f[3] - f[1]))
}

/// (device box, text box) as [x0, y0, x1, y1] fractions of the canvas.
let defaultBoxes: (device: [CGFloat], text: [CGFloat]) = {
    if kind == "header" { return ([0.455, 0.06, 0.885, 0.94], [0.10, 0.12, 0.43, 0.88]) }
    if layout == "side" { return ([0.40, 0.06, 0.965, 0.94], [0.065, 0.10, 0.385, 0.90]) }
    return ([0.05, 0.255, 0.95, 0.965], [0.06, 0.045, 0.94, 0.235])
}()
let deviceBox = fractionBox("device-box", defaultBoxes.device)
let textBox = fractionBox("text-box", defaultBoxes.text)

/// Apple's template safe areas (measured by others) and what an iPhone in portrait shows. Snapjaw's art is judged on the
/// iPhone view: the header loses about 8 % per side there (the back and share buttons over its top corners); the
/// search card is shown whole.
let safeArea: CGRect = kind == "header"
    ? CGRect(x: 1097, y: 493, width: 2743 - 1097, height: 1154 - 493)
    : CGRect(x: 836, y: 765, width: 3004 - 836, height: 1795 - 765)
let iphoneArea: CGRect = kind == "header"
    ? CGRect(x: W * 0.09, y: H * 0.05, width: W * 0.82, height: H * 0.90)
    : CGRect(x: W * 0.03, y: H * 0.03, width: W * 0.94, height: H * 0.94)

/// Debug (--snaps <dir>): the canvas after each stage.
var snapCount = 0
func writePNG(_ image: CGImage, _ path: String) {
    guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString,
                                                            1, nil) else { fail("cannot create \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot write \(path)") }
}
func snap(_ name: String) {
    guard let dir = options["snaps"], !dir.isEmpty, dir != "1", let image = ctx.makeImage() else { return }
    snapCount += 1
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    writePNG(image, (dir as NSString).appendingPathComponent(String(format: "%02d-%@.png", snapCount, name)))
}

// MARK: Background (store-frame.swift's: the bog → moss sweep, the lime glow, a crimson ember, a floor shade)

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
    // Behind the book, leaning toward its lit page (the HUD's half), so the device sits in the light.
    let gx = num("glow-x", (lightLeft ? deviceBox.minX + deviceBox.width * 0.40 : deviceBox.minX + deviceBox.width * 0.60) / W)
    let centre = cgp(CGPoint(x: W * gx, y: H * 0.45))
    ctx.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre,
                           endRadius: max(W, H) * 0.42, options: [])
}
if let ember = CGGradient(colorsSpace: space, colors: [srgb(crimson, 0.09), srgb(crimson, 0)] as CFArray,
                          locations: [0, 1]) {
    // A faint crimson ember in the top corner away from the light: the trap's colour, kept away from the type.
    let centre = cgp(CGPoint(x: lightLeft ? W * 0.97 : W * 0.03, y: H * 0.04))
    ctx.drawRadialGradient(ember, startCenter: centre, startRadius: 0, endCenter: centre,
                           endRadius: max(W, H) * 0.30, options: [])
}
ctx.restoreGState()
if let floor = CGGradient(colorsSpace: space, colors: [srgb(shadowInk, 0.40), srgb(shadowInk, 0)] as CFArray,
                          locations: [0, 1]) {
    ctx.drawLinearGradient(floor, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: H * 0.30), options: [])
}
snap("background")

// MARK: The book (ci/store-frame.swift's drawBook, fitted into deviceBox)

/// Core Image renders the warps. A paravirtual GPU can refuse, so a software context is the fallback.
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
/// (bottom-left-origin pixel coordinates of the output). First a Lanczos scale to about the drawn size (the banner
/// draws a half at ~0.55–0.9 x, and a bilinear perspective warp alone would alias the UI's fine lines).
func warp(_ image: CGImage, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) -> (image: CGImage, rect: CGRect)? {
    var input = CIImage(cgImage: image)
    let drawnW = max(hypot(tr.x - tl.x, tr.y - tl.y), hypot(br.x - bl.x, br.y - bl.y))
    let drawnH = max(hypot(bl.x - tl.x, bl.y - tl.y), hypot(br.x - tr.x, br.y - tr.y))
    let kx = min(1, drawnW * 1.15 / CGFloat(image.width))
    let ky = min(1, drawnH * 1.15 / CGFloat(image.height))
    if kx > 0.01, ky > 0.01, kx < 0.999 || ky < 0.999, let scaler = CIFilter(name: "CILanczosScaleTransform") {
        scaler.setValue(input, forKey: kCIInputImageKey)
        scaler.setValue(NSNumber(value: Double(ky)), forKey: kCIInputScaleKey)
        scaler.setValue(NSNumber(value: Double(kx / ky)), forKey: kCIInputAspectRatioKey)
        if let scaled = scaler.outputImage { input = scaled }
    }
    guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }
    filter.setValue(input, forKey: kCIInputImageKey)
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

/// Self-test of the warp's corner convention: a four-colour card (red top-left, green top-right, blue bottom-left,
/// white bottom-right) warped onto an upright square and read back. Which flips the real warps need, or nil.
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
func pointBounds(_ points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .zero }
    var lo = first, hi = first
    for p in points {
        lo.x = min(lo.x, p.x); lo.y = min(lo.y, p.y)
        hi.x = max(hi.x, p.x); hi.y = max(hi.y, p.y)
    }
    return CGRect(x: lo.x, y: lo.y, width: hi.x - lo.x, height: hi.y - lo.y)
}

var bookReport = ""
var deviceRectTL = CGRect.null      // top-left coordinates
var devicePaths: [CGPath] = []      // Core Graphics coordinates (for the text overlap check)

func drawBook(_ shot: CGImage, in boxTL: CGRect) {
    let iw = shot.width, ih = shot.height
    var fold = Int((Double(iw) * 1428.0 / 2853.0).rounded())
    if let text = options["fold"], let f = Int(text) { fold = f }
    fold = max(1, min(iw - 1, fold))
    let wl = Double(fold), wr = Double(iw - fold), h = Double(ih)
    let angle = max(100, min(175, number("angle", 140)))
    let theta = (180 - angle) / 2 * Double.pi / 180      // each page turned this far toward the viewer
    let tilt = max(-30, min(30, number("tilt", 8))) * Double.pi / 180
    // Negative yaw turns the book's face a little toward the left (the text column) when it stands on the right.
    let yaw = max(-30, min(30, number("yaw", layout == "top" ? 0 : -5))) * Double.pi / 180
    let bezel = h * 0.024
    let deviceRadius = h * 0.065
    let screenRadius = max(0, deviceRadius - bezel)
    let distance = h * 3.4                              // camera distance from the spine: mild perspective
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

    // Fit the projected device into the box (a little headroom below for the ground shadow), as store-frame does.
    var raw: [CGPoint] = spineWorld.map(project)
    raw += leftBody.map { project(page(-1, $0.0, $0.1)) }
    raw += rightBody.map { project(page(1, $0.0, $0.1)) }
    let minX = raw.map(\.x).min() ?? 0, maxX = raw.map(\.x).max() ?? 1
    let minY = raw.map(\.y).min() ?? 0, maxY = raw.map(\.y).max() ?? 1
    let box = cg(boxTL)
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
    let spineRect = pointBounds(spineWorld.map { place(project($0)) })
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

    // The body: one soft drop shadow for both pages, then each page's bezel (the page on the light's side is lit).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -deviceBounds.height * 0.018), blur: deviceBounds.height * 0.065,
                  color: srgb(0x000000, 0.55))
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
        ctx.setLineWidth(max(1, deviceBounds.height * 0.0024))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // The screens: each half of the capture, only resampled and warped, clipped to the display's outline.
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
        let expected = pointBounds([tl, tr, bl, br])
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
    ctx.setLineWidth(max(1, deviceBounds.height * 0.0027))
    ctx.move(to: at(1, 0, h / 2)); ctx.addLine(to: at(1, 0, h / 2 + bezel))
    ctx.move(to: at(1, 0, -h / 2)); ctx.addLine(to: at(1, 0, -h / 2 - bezel))
    ctx.strokePath()
    ctx.restoreGState()

    deviceRectTL = toTL(deviceBounds.union(spineRect))
    devicePaths = [leftBodyPath, rightBodyPath, spinePath]
    let flips = (convention.flipV ? "V" : "") + (convention.flipH ? "H" : "")
    bookReport = " angle=\(Int(angle.rounded())) fold=\(fold) warp=\(flips.isEmpty ? "ok" : "flip" + flips)"
        + " extent=\(extentOK ? "ok" : "mismatch")" + (usedSoftwareCI ? " ci=software" : "")
        + " light=\(lightLeft ? "left" : "right")"
}

drawBook(hero, in: deviceBox)
snap("book")

// MARK: Type (ci/store-frame.swift's caption system: `*word*` highlight, balanced lines, the gold swash)

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

struct Laid {
    var lines: [CTLine] = []
    var highlights: [[NSRange]] = []
    var widths: [CGFloat] = []
    var lineHeight: CGFloat = 0
    var ascentShare: CGFloat = 0.8
    var size: CGFloat = 0
    var capHeight: CGFloat = 0
    var height: CGFloat { lineHeight * CGFloat(lines.count) }
    var maxWidth: CGFloat { widths.max() ?? 0 }
}

func lay(_ words: Words, _ style: Style, width: CGFloat, leading: CGFloat) -> Laid {
    var laid = Laid()
    let ascent = CTFontGetAscent(style.font), descent = CTFontGetDescent(style.font)
    laid.lineHeight = (ascent + descent) * leading
    laid.ascentShare = ascent / max(ascent + descent, 1)
    laid.size = CTFontGetSize(style.font)
    laid.capHeight = CTFontGetCapHeight(style.font)
    for lineWords in balanced(words, width, style) {
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

var textRect = CGRect.null       // top-left coordinates, ink extents
var textPieces: [CGRect] = []    // each line, swash and capsule (for the overlap check)
func addText(_ r: CGRect) { textRect = textRect.union(r); textPieces.append(r) }

/// Draws laid lines from `top`: left-aligned at `x`, or centred on `x` (top-left coordinates).
func drawLaid(_ laid: Laid, top: CGFloat, x: CGFloat, centred: Bool) {
    for (i, line) in laid.lines.enumerated() {
        let lineTop = top + CGFloat(i) * laid.lineHeight
        let baseline = lineTop + laid.lineHeight * laid.ascentShare
        let lx = centred ? x - laid.widths[i] / 2 : x
        let baseCG = H - baseline
        for range in laid.highlights[i] {
            // The marker swash: bog-ink letters on nectar gold, slightly tilted like a highlighter stroke.
            let x0 = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let x1 = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)
            let pad = laid.size * 0.10
            let swash = CGRect(x: lx + x0 - pad, y: baseCG - laid.size * 0.15,
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
            addText(toTL(swash.insetBy(dx: -swash.height * 0.02, dy: -swash.height * 0.02)))
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: lx, y: baseCG)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
        let inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        addText(CGRect(x: lx + inkBounds.minX, y: baseline - inkBounds.maxY, width: inkBounds.width, height: inkBounds.height))
    }
}

/// The app's Home title (Snap/UI/HomeView.swift with SnapTheme / SnapType.wordmark): "Snapjaw" (AppBrand.name) in
/// Rounded Black, kern −1.5 %, filled top to bottom from cream to light lime, over a hard crimson-deep shadow
/// 0.05 × size straight down (the app's 4 pt at 78 pt); 0.06 × size under it the tagline (AppBrand.tagline) in Rounded
/// Bold cream at 0.21 × size; both leading-aligned.
struct Mark {
    var size: CGFloat
    var title: Laid
    var shade: Laid
    var tagline: Laid
    var gap: CGFloat
    var drop: CGFloat { size * 0.05 }
    var width: CGFloat { max(title.maxWidth, tagline.maxWidth + size * 0.02) }
    var height: CGFloat { title.height + drop + gap + tagline.height }
}
func makeMark(_ size: CGFloat) -> Mark {
    let kern = -size * 0.015
    let title = lay(tokenize("Snapjaw"), Style(font: roundedFont(size, .black), color: srgb(cream), hiColor: srgb(cream),
                                               kern: kern), width: 100_000, leading: 1.0)
    let shade = lay(tokenize("Snapjaw"), Style(font: roundedFont(size, .black), color: srgb(crimsonDeep),
                                               hiColor: srgb(crimsonDeep), kern: kern), width: 100_000, leading: 1.0)
    let tagline = lay(tokenize("Feed the flytrap. Spare bees."),
                      Style(font: roundedFont(max(size * 0.21, 11), .bold), color: srgb(cream), hiColor: srgb(cream),
                            kern: 0), width: 100_000, leading: 1.0)
    return Mark(size: size, title: title, shade: shade, tagline: tagline, gap: size * 0.06)
}
func drawMark(_ m: Mark, left: CGFloat, top: CGFloat) {
    // The hard shadow first, then the title's glyphs as a clip, filled with the cream → light lime gradient.
    drawLaid(m.shade, top: top + m.drop, x: left, centred: false)
    if let line = m.title.lines.first {
        let baseline = top + m.title.lineHeight * m.title.ascentShare     // top-left origin
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: left, y: H - baseline)
        ctx.setTextDrawingMode(.clip)
        CTLineDraw(line, ctx)
        if let g = CGGradient(colorsSpace: space, colors: [srgb(cream), srgb(limeLight)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: left, y: H - top), end: CGPoint(x: left, y: H - top - m.title.lineHeight),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.restoreGState()
        let glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        addText(CGRect(x: left + glyphs.minX, y: baseline - glyphs.maxY, width: glyphs.width, height: glyphs.height + m.drop))
    }
    drawLaid(m.tagline, top: top + m.title.height + m.drop + m.gap, x: left + m.size * 0.02, centred: false)
}

let captionParts = rawCaption.components(separatedBy: " / ")
let headText = (captionParts.first ?? "").trimmingCharacters(in: .whitespaces)
let subText = captionParts.count > 1 ? captionParts.dropFirst().joined(separator: " / ").trimmingCharacters(in: .whitespaces) : ""
let probeFont = roundedFont(100, .heavy)
let capRatio = max(CTFontGetCapHeight(probeFont) / 100, 0.5)

/// The headline (Heavy, dew white, one gold swash) at the largest cap height from `capStart` down (5 % steps, floor
/// `capFloor`) that fits `maxLines` lines in `width`, plus the sub-line (Semibold mist green at 46 %, shrunk to `subLines`
/// lines, floor 36 %). Returns the two blocks and the gap between them.
func layCaption(width: CGFloat, maxHeight: CGFloat, capStart: CGFloat, capFloor: CGFloat, maxLines: Int,
                subLines: Int) -> (head: Laid, sub: Laid?, gap: CGFloat) {
    let headWords = tokenize(headText)
    let subWords = tokenize(subText.replacingOccurrences(of: "*", with: ""))
    var cap = capStart
    var result = (head: Laid(), sub: Laid?.none, gap: CGFloat(0))
    for _ in 0..<60 {
        let size = cap / capRatio
        let head = lay(headWords, Style(font: roundedFont(size, .heavy), color: srgb(dew), hiColor: srgb(bogInk),
                                        kern: -0.008 * size), width: width, leading: 0.92)
        var sub: Laid? = nil
        if !subWords.isEmpty {
            var subSize = size * 0.46
            var laidSub = Laid()
            while true {
                laidSub = lay(subWords, Style(font: roundedFont(subSize, .semibold), color: srgb(mistGreen), hiColor: srgb(mistGreen),
                                              kern: 0), width: width, leading: 1.05)
                if laidSub.lines.count <= subLines || subSize <= size * 0.36 { break }
                subSize = max(size * 0.36, subSize * 0.95)
            }
            sub = laidSub
        }
        let gap: CGFloat = sub == nil ? 0 : size * 0.30
        let total = head.height + gap + (sub?.height ?? 0)
        result = (head: head, sub: sub, gap: gap)
        if (head.lines.count <= maxLines && head.maxWidth <= width && total <= maxHeight) || cap <= capFloor { break }
        cap = max(capFloor, cap * 0.95)
    }
    return result
}

var reportCap: CGFloat = 0
let tb = textBox
if kind == "header" {
    // The wordmark, big, centred in the column; the icon, the name and the subtitle sit right under the art on the
    // page, so no headline repeats them. An optional --caption headline goes under it as a second tagline (Heavy,
    // mist green).
    var markSize = H * num("mark", 0.20)
    var mark = makeMark(markSize)
    if mark.width > tb.width { markSize *= tb.width / mark.width; mark = makeMark(markSize) }
    var tag: Laid? = nil
    if !headText.isEmpty {
        let tagSize = markSize * num("tag", 0.30)
        tag = lay(tokenize(headText.replacingOccurrences(of: "*", with: "")),
                  Style(font: roundedFont(tagSize, .heavy), color: srgb(mistGreen), hiColor: srgb(mistGreen), kern: 0),
                  width: tb.width, leading: 1.0)
    }
    let tagGap = markSize * 0.16
    let total = mark.height + (tag.map { tagGap + $0.height } ?? 0)
    let blockW = max(mark.width, tag?.maxWidth ?? 0)
    let top = tb.midY - total / 2
    let left = tb.midX - blockW / 2
    drawMark(mark, left: left, top: top)
    if let tag { drawLaid(tag, top: top + mark.height + tagGap, x: left + markSize * 0.02, centred: false) }
    reportCap = CTFontGetCapHeight(roundedFont(markSize, .black))
} else if layout == "side" {
    // Small wordmark, the headline in up to three lines, the sub-line; left-aligned, centred on the column.
    let laid = layCaption(width: tb.width, maxHeight: tb.height * 0.78, capStart: H * num("cap", 0.075),
                          capFloor: H * 0.045, maxLines: 3, subLines: 2)
    let mark = makeMark(laid.head.size * 0.62)
    let markGap = laid.head.size * 0.34
    let total = mark.height + markGap + laid.head.height + laid.gap + (laid.sub?.height ?? 0)
    let top = tb.midY - total / 2
    drawMark(mark, left: tb.minX + laid.head.size * 0.03, top: top)
    drawLaid(laid.head, top: top + mark.height + markGap, x: tb.minX, centred: false)
    if let sub = laid.sub {
        drawLaid(sub, top: top + mark.height + markGap + laid.head.height + laid.gap, x: tb.minX + laid.head.size * 0.03,
                 centred: false)
    }
    reportCap = laid.head.capHeight
} else {
    // Top: the headline on one line and the sub-line under it, centred across the top band.
    let laid = layCaption(width: tb.width, maxHeight: tb.height, capStart: H * num("cap", 0.062),
                          capFloor: H * 0.036, maxLines: Int(number("lines", 1)), subLines: 1)
    let total = laid.head.height + laid.gap + (laid.sub?.height ?? 0)
    let top = max(tb.minY, tb.midY - total / 2)
    drawLaid(laid.head, top: top, x: tb.midX, centred: true)
    if let sub = laid.sub { drawLaid(sub, top: top + laid.head.height + laid.gap, x: tb.midX, centred: true) }
    reportCap = laid.head.capHeight
}
snap("text")

// MARK: Output (opaque sRGB PNG, no alpha), plus the optional review copy with guides

guard let flat = ctx.makeImage() else { fail("cannot flatten") }
writePNG(flat, output)

if let guides = options["guides"], !guides.isEmpty, guides != "1" {
    ctx.saveGState()
    ctx.setLineWidth(6)
    ctx.setStrokeColor(srgb(0xE5484D, 0.9))
    ctx.setLineDash(phase: 0, lengths: [28, 18])
    ctx.stroke(cg(safeArea))
    ctx.setStrokeColor(srgb(0x5CC2D6, 0.9))
    ctx.stroke(cg(iphoneArea))
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.setStrokeColor(srgb(dew, 0.5))
    ctx.setLineWidth(3)
    ctx.move(to: CGPoint(x: 0, y: H / 2)); ctx.addLine(to: CGPoint(x: W, y: H / 2))
    ctx.move(to: CGPoint(x: W / 2, y: 0)); ctx.addLine(to: CGPoint(x: W / 2, y: H))
    ctx.strokePath()
    ctx.restoreGState()
    if let g = ctx.makeImage() { writePNG(g, guides) }
}

// Does any piece of text come within 1.2 % of the image height of the device?
var overlap = false
let devicePath = CGMutablePath()
for p in devicePaths { devicePath.addPath(p) }
for piece in textPieces {
    let grown = piece.insetBy(dx: -H * 0.012, dy: -H * 0.012)
    if #available(macOS 13.0, *) {
        if CGPath(rect: cg(grown), transform: nil).intersects(devicePath) { overlap = true }
    } else if grown.intersects(deviceRectTL) {
        overlap = true
    }
}

func rectText(_ v: CGRect) -> String { v.isNull ? "-" : "\(Int(v.minX)),\(Int(v.minY)),\(Int(v.width))x\(Int(v.height))" }
let canvas = CGRect(x: 0, y: 0, width: W, height: H)
let textIPhone = !textRect.isNull && iphoneArea.contains(textRect) && canvas.contains(textRect)
let textTemplate = !textRect.isNull && safeArea.contains(textRect)
let deviceCentre = CGPoint(x: deviceRectTL.midX, y: deviceRectTL.midY)
let deviceInTemplate = safeArea.contains(deviceCentre)
let deviceIPhone = iphoneArea.contains(deviceRectTL)
let capPercent = String(format: "%.1f", Double(reportCap / H * 100))
func yesNo(_ b: Bool) -> String { b ? "yes" : "no" }
var report = "store-banner: \(output) \(width)x\(height) kind=\(kind) layout=\(layout) cap=\(capPercent)%"
report += " device=\(rectText(deviceRectTL)) text=\(rectText(textRect))"
report += " text-iphone=\(yesNo(textIPhone)) device-iphone=\(yesNo(deviceIPhone)) overlap=\(yesNo(overlap))"
report += " text-in-template-safe=\(yesNo(textTemplate)) device-centre-in-template-safe=\(yesNo(deviceInTemplate))"
report += " rounded=\(yesNo(usedRounded))"
report += bookReport
print(report)
