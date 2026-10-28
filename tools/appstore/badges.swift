// badges.swift: collects Snapjaw's 12 Game Center achievement images for asc.swift.
//
//   xcrun swift tools/appstore/badges.swift [--from <dir>] [--out <dir>]
//
// Snapjaw draws its badges itself (docs/appstore/achievements.md "Images": AchievementBadge(id:) in
// Snap/UI/AchievementArt.swift, from TrapArt paths). The App engineer's ask there: the demo key `screen=badges`
// renders all twelve into Documents/badges/<id>.png at 1024 x 1024 and logs `SNAP-T badges done <n>`; a CI scenario
// `badges` (ci/scenarios.txt) copies them into the `screenshots` artifact, folder badges/ (logs/badges.txt). Until
// that exists, run it without --from: it checks the IDs only (asc.yml does that and warns that the images are a gap).
// Point --from at that folder. This script does not redraw anything: it
//   1. checks the IDs: the app's list (`Achievements.all` in Snap/Core/Progression.swift, each
//      `static let <x> = def("<key>", …)` being the Game Center ID "snap.ach.<key>", which is what
//      GameCenterManager.achievementIDs reports), the IDs in docs/appstore/achievements.md and, if it exists, the
//      achievements in docs/appstore/asc-metadata.json; with --from also the rendered PNG names;
//   2. checks each image is 1024 x 1024;
//   3. writes it to <out>/<id>.png as an opaque sRGB PNG at 72 ppi (Game Center asks for RGB without transparency).
//      The app should render opaque; any pixel that isn't fully opaque is first composited onto the badge's deep bog
//      green #0A2414 (SnapTheme.bogDeep, achievements.md "deep bog green"), and the count is printed (0 expected);
//   4. writes <out>/preview.png, a 4 x 3 contact sheet.
// Default <out> is tools/appstore/badges. Exits 1 on any mismatch or unreadable image. Ported from the sister book-pose
// game's badges.swift (it collected the badges that game shipped with), with Snapjaw's ID source and background.

import CoreGraphics
import Foundation
import ImageIO

let expectedCount = 12
let gameCenterSource = "Snap/App/GameCenterManager.swift"
let achievementSources = ["Snap/Core/Progression.swift", "Snap/App/GameCenterManager.swift"]
/// Core's `def("feast", …)` is the Game Center achievement "snap.ach.feast" (GameCenterManager.gameCenterID).
let achievementIDPrefix = "snap.ach."

let scriptURL = URL(fileURLWithPath: #filePath).standardizedFileURL
let scriptDir = scriptURL.deletingLastPathComponent()
let repoRoot: URL = {
    if let r = ProcessInfo.processInfo.environment["ASC_REPO_ROOT"], !r.isEmpty { return URL(fileURLWithPath: r) }
    let guess = scriptDir.deletingLastPathComponent().deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: guess.appendingPathComponent(gameCenterSource).path) { return guess }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}()

func fail(_ s: String) -> Never {
    FileHandle.standardError.write("error: \(s)\n".data(using: .utf8)!)
    exit(1)
}

var fromDir: URL? = nil
var outDir = scriptDir.appendingPathComponent("badges")
do {
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let a = args.removeFirst()
        switch a {
        case "--from":
            guard !args.isEmpty else { fail("--from needs a directory") }
            fromDir = URL(fileURLWithPath: args.removeFirst())
        case "--out":
            guard !args.isEmpty else { fail("--out needs a directory") }
            outDir = URL(fileURLWithPath: args.removeFirst())
        case "-h", "--help":
            print("usage: xcrun swift tools/appstore/badges.swift --from <screenshots artifact>/badges [--out <dir>]")
            exit(0)
        default:
            fail("unknown argument \(a)")
        }
    }
}

// MARK: - The IDs, from three places

func quoted(_ s: Substring) -> [String] {
    var found: [String] = []
    var rest = s
    while let open = rest.firstIndex(of: "\"") {
        let after = rest.index(after: open)
        guard let close = rest[after...].firstIndex(of: "\"") else { break }
        found.append(String(rest[after..<close]))
        rest = rest[rest.index(after: close)...]
    }
    return found
}

func repoText(_ rel: String) -> String? {
    try? String(contentsOf: repoRoot.appendingPathComponent(rel), encoding: .utf8)
}

/// The body of the array literal in `static let <name>[: T] = [ ... ]`, or nil when it isn't an array literal.
func arrayLiteral(named name: String, in text: String) -> String? {
    guard let start = text.range(of: "static let \(name)") else { return nil }
    let rest = text[start.upperBound...]
    guard let eq = rest.firstIndex(of: "=") else { return nil }
    let value = rest[rest.index(after: eq)...].drop { $0 == " " || $0 == "\t" }
    guard value.first == "[" else { return nil }
    let body = value.dropFirst()
    guard let close = body.firstIndex(of: "]") else { return nil }
    return String(body[..<close])
}

/// `static let <ident>[: String] = "<value>"` in any of `texts`.
func stringConstant(_ ident: String, in texts: [String]) -> String? {
    let pattern = "static let \(NSRegularExpression.escapedPattern(for: ident))\\s*(:\\s*String\\s*)?=\\s*\"([^\"]*)\""
    guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
    for t in texts {
        let ns = t as NSString
        if let match = re.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)),
           match.range(at: 2).location != NSNotFound {
            return ns.substring(with: match.range(at: 2))
        }
    }
    return nil
}

/// Array items: quoted strings as they are, identifiers resolved through their `static let … = "…"`.
func resolveItems(_ body: String, _ texts: [String]) -> [String]? {
    let code = body.components(separatedBy: .newlines).map { line -> String in
        if let r = line.range(of: "//") { return String(line[..<r.lowerBound]) }
        return line
    }.joined(separator: " ")
    var ids: [String] = []
    for raw in code.split(separator: ",") {
        let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.isEmpty { continue }
        if item.hasPrefix("\"") { ids += quoted(Substring(item)); continue }
        let ident = item.split(separator: ".").last.map { String($0) } ?? item
        guard let value = stringConstant(ident, in: texts) else { return nil }
        ids.append(value)
    }
    return ids
}

/// Snapjaw: `static let all: [AchievementDef] = [feast, bite5, …]` (Snap/Core/Progression.swift), each item a
/// `static let feast = def("feast", …)`. Nil when the list or an item can't be read.
func snapjawIDs(_ texts: [String]) -> [String]? {
    for t in texts {
        guard let body = arrayLiteral(named: "all", in: t) else { continue }
        let code = body.components(separatedBy: .newlines).map { line -> String in
            if let r = line.range(of: "//") { return String(line[..<r.lowerBound]) }
            return line
        }.joined(separator: " ")
        var ids: [String] = []
        for raw in code.split(separator: ",") {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.isEmpty { continue }
            if item.hasPrefix("\"") { ids += quoted(Substring(item)); continue }
            let ident = item.split(separator: ".").last.map { String($0) } ?? item
            let pattern = "static let \(NSRegularExpression.escapedPattern(for: ident))\\s*(:\\s*AchievementDef\\s*)?=\\s*def\\(\\s*\"([^\"]+)\""
            guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
            let ns = t as NSString
            guard let match = re.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)),
                  match.range(at: 2).location != NSNotFound else { return nil }
            let key = ns.substring(with: match.range(at: 2))
            ids.append(key.hasPrefix(achievementIDPrefix) ? key : achievementIDPrefix + key)
        }
        if !ids.isEmpty { return ids }
    }
    return nil
}

/// The app's achievement IDs: Snapjaw's `Achievements.all` (above), else GameCenterManager.achievementIDs as a
/// literal list or a reference such as `SomeType.allAchievements` (the sister apps' forms).
func appIDs() -> [String] {
    let texts = achievementSources.compactMap { repoText($0) }
    if let ids = snapjawIDs(texts) { return ids }
    guard let gc = repoText(gameCenterSource) else { fail("\(gameCenterSource) not found under \(repoRoot.path)") }
    if let body = arrayLiteral(named: "achievementIDs", in: gc) {
        guard let ids = resolveItems(body, texts + [gc]), !ids.isEmpty else { fail("\(gameCenterSource): achievementIDs could not be read") }
        return ids
    }
    guard let start = gc.range(of: "static let achievementIDs"),
          let eq = gc[start.upperBound...].firstIndex(of: "=") else { fail("\(gameCenterSource): achievementIDs not found") }
    let rhs = gc[gc.index(after: eq)...].prefix { $0 != "\n" }.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let listName = rhs.split(separator: ".").last.map({ String($0) }), !listName.isEmpty else {
        fail("\(gameCenterSource): achievementIDs = \(rhs) is not a list or a reference to one")
    }
    for t in texts {
        if let body = arrayLiteral(named: listName, in: t), let ids = resolveItems(body, texts), !ids.isEmpty { return ids }
    }
    fail("achievementIDs = \(rhs): list \(listName) not found or not resolvable in \(achievementSources.joined(separator: ", "))")
}

func docIDs() -> [String] {
    let url = repoRoot.appendingPathComponent("docs/appstore/achievements.md")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { fail("\(url.path) not found") }
    // Table rows: | 1 | `snap.ach.feast` | ...
    return text.components(separatedBy: .newlines).compactMap { line in
        guard line.range(of: "^\\| [0-9]+ \\| `", options: .regularExpression) != nil else { return nil }
        let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        return cells.count > 1 ? cells[1].replacingOccurrences(of: "`", with: "") : nil
    }
}

func metadataIDs() -> [String]? {
    let url = repoRoot.appendingPathComponent("docs/appstore/asc-metadata.json")
    guard let data = try? Data(contentsOf: url),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let list = root["achievements"] as? [[String: Any]] else { return nil }
    return list.compactMap { $0["vendorIdentifier"] as? String }
}

let ids = appIDs()
guard ids.count == expectedCount else { fail("GameCenterManager.achievementIDs has \(ids.count) IDs, expected \(expectedCount)") }
var mismatch = false
func compare(_ name: String, _ other: [String]?) {
    guard let other = other else { print("  \(name): not found, skipped"); return }
    let a = Set(ids), b = Set(other)
    if a == b && other.count == ids.count { print("  \(name): same \(ids.count) IDs"); return }
    mismatch = true
    print("  \(name): MISMATCH. Missing: \(a.subtracting(b).sorted().joined(separator: ", ")). Extra: \(b.subtracting(a).sorted().joined(separator: ", "))")
}
print("IDs (GameCenterManager.achievementIDs): \(ids.joined(separator: ", "))")
compare("docs/appstore/achievements.md", docIDs())
compare("docs/appstore/asc-metadata.json", metadataIDs())

guard let from = fromDir else {
    if mismatch { fail("achievement IDs differ") }
    print("No --from given: IDs checked, no images collected.")
    exit(0)
}
let files = ((try? FileManager.default.contentsOfDirectory(atPath: from.path)) ?? []).filter { $0.hasSuffix(".png") }
compare("\(from.path) (rendered by the app)", files.map { String($0.dropLast(4)) })
if mismatch { fail("achievement IDs differ") }

// MARK: - Flatten and write

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

/// Number of pixels whose alpha is below 255.
func translucentPixels(_ image: CGImage) -> Int {
    let w = image.width, h = image.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var n = 0
    var i = 3
    while i < buf.count { if buf[i] < 255 { n += 1 }; i += 4 }
    return n
}

func opaqueCopy(_ image: CGImage, size: Int) -> CGImage {
    // noneSkipLast: RGB with no alpha channel in the written PNG. Background: the badges' deep bog green #0A2414.
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(CGColor(srgbRed: 0x0A / 255.0, green: 0x24 / 255.0, blue: 0x14 / 255.0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { fail("can't write \(url.path)") }
    let props: [CFString: Any] = [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72, kCGImagePropertyHasAlpha: false]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fail("can't finalise \(url.path)") }
}

/// Byte 25 (colour type) of the IHDR chunk: 2 = RGB, 6 = RGBA.
func pngColourType(_ url: URL) -> UInt8? {
    guard let d = try? Data(contentsOf: url), d.count > 25 else { return nil }
    return d[25]
}

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
var flattened: [CGImage] = []
var failed = false
for id in ids {
    let src = from.appendingPathComponent("\(id).png")
    guard let img = load(src) else { print("  \(id): can't read \(src.path)"); failed = true; continue }
    guard img.width == 1024 && img.height == 1024 else { print("  \(id): \(img.width)x\(img.height), Game Center needs 1024x1024"); failed = true; continue }
    let translucent = translucentPixels(img)
    let opaque = opaqueCopy(img, size: 1024)
    let dst = outDir.appendingPathComponent("\(id).png")
    writePNG(opaque, to: dst)
    let bytes = (try? FileManager.default.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? 0
    let ct = pngColourType(dst).map { $0 == 2 ? "RGB" : "colour type \($0)" } ?? "?"
    print("  \(id): 1024x1024, \(translucent) translucent px\(translucent > 0 ? " flattened onto bog green" : ""), wrote \(ct) PNG \(bytes / 1024) KB")
    if pngColourType(dst) != 2 { print("  \(id): the written PNG is not plain RGB"); failed = true }
    flattened.append(opaque)
}
if failed { fail("some badges could not be collected") }

// Contact sheet: 4 x 3 at 256 px with 16 px gaps.
let cell = 256, gap = 16, cols = 4, rows = (flattened.count + 3) / 4
let sheetW = cols * cell + (cols + 1) * gap, sheetH = rows * cell + (rows + 1) * gap
let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
sheet.setFillColor(CGColor(srgbRed: 0.03, green: 0.11, blue: 0.07, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
sheet.interpolationQuality = .high
for (i, img) in flattened.enumerated() {
    let c = i % cols, r = i / cols
    let x = gap + c * (cell + gap), y = sheetH - (gap + (r + 1) * cell + r * gap)
    sheet.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell))
}
writePNG(sheet.makeImage()!, to: outDir.appendingPathComponent("preview.png"))
print("OK: \(flattened.count) badges in \(outDir.path) (+ preview.png)")
