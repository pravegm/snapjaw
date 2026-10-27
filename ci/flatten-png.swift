// Rewrites each PNG given as an argument as opaque RGB (no alpha channel), drawn over white. The App Store icon must
// carry no alpha channel even when every pixel is opaque (QA-FINAL-release P2). Usage: xcrun swift ci/flatten-png.swift a.png ...
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

var failed = false
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        print("flatten: cannot read \(path)"); failed = true; continue
    }
    let w = image.width, h = image.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        print("flatten: no context for \(path)"); failed = true; continue
    }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let flat = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("flatten: cannot write \(path)"); failed = true; continue
    }
    CGImageDestinationAddImage(dest, flat, nil)
    if CGImageDestinationFinalize(dest) {
        print("flatten: \(path) \(w)x\(h) alpha=\(image.alphaInfo.rawValue) -> opaque RGB")
    } else {
        print("flatten: finalize failed for \(path)"); failed = true
    }
}
exit(failed ? 1 : 0)
