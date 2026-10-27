import Compression
import CoreGraphics
import Foundation

/// A PNG with NO alpha channel (colour type 2, 8-bit RGB), for the App Store icon (ITMS-90717 refuses a 1024 icon
/// with an alpha channel, even a fully opaque one) and the Game Center badges. UIKit's `pngData()` writes RGBA even
/// for an opaque renderer, so the bytes are written here: the image is drawn onto an opaque background, every row
/// is stored unfiltered, and the zlib stream wraps Compression's raw DEFLATE. Pure; tested.
enum SnapPNG {
    static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Encodes `image` (any format) as an RGB PNG of the same pixel size, flattened onto `background` (black).
    static func encode(_ image: CGImage, background: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)) -> Data? {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            ctx.setFillColor(background)
            ctx.fill(rect)
            ctx.draw(image, in: rect)
            return true
        }
        guard drawn else { return nil }
        return encodeRGB(rgbaRows: rgba, width: w, height: h)
    }

    /// Rows of RGBX bytes (top row first) → an RGB PNG.
    static func encodeRGB(rgbaRows rgba: [UInt8], width w: Int, height h: Int) -> Data? {
        guard w > 0, h > 0, rgba.count >= w * h * 4 else { return nil }
        let stride = 1 + 3 * w
        var raw = [UInt8](repeating: 0, count: stride * h)
        rgba.withUnsafeBufferPointer { src in
            raw.withUnsafeMutableBufferPointer { dst in
                for y in 0..<h {
                    var o = y * stride + 1           // byte 0 of each row: filter type 0 (none)
                    var i = y * w * 4
                    for _ in 0..<w {
                        dst[o] = src[i]; dst[o + 1] = src[i + 1]; dst[o + 2] = src[i + 2]
                        o += 3
                        i += 4
                    }
                }
            }
        }
        guard let deflated = deflate(raw) else { return nil }
        var zlib: [UInt8] = [0x78, 0x01]               // CMF/FLG: deflate, 32K window, (0x7801 % 31 == 0)
        zlib += deflated
        zlib += bigEndian(adler32(raw))

        var ihdr: [UInt8] = bigEndian(UInt32(w)) + bigEndian(UInt32(h))
        ihdr += [8, 2, 0, 0, 0]                         // 8-bit, colour type 2 (RGB), deflate, no filter set, no interlace
        var out = signature
        out += chunk("IHDR", ihdr)
        out += chunk("IDAT", zlib)
        out += chunk("IEND", [])
        return Data(out)
    }

    /// The PNG's colour type byte (IHDR), for tests and CI (2 = RGB, 6 = RGBA).
    static func colorType(_ png: Data) -> UInt8? {
        guard png.count > 25, Array(png.prefix(8)) == signature else { return nil }
        return png[png.startIndex + 25]
    }

    // MARK: - Pieces

    private static func deflate(_ input: [UInt8]) -> [UInt8]? {
        let capacity = input.count + input.count / 2 + 4_096
        var output = [UInt8](repeating: 0, count: capacity)
        let written = input.withUnsafeBufferPointer { src -> Int in
            output.withUnsafeMutableBufferPointer { dst -> Int in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return 0 }
                return compression_encode_buffer(d, capacity, s, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return Array(output.prefix(written))
    }

    static func adler32(_ data: [UInt8]) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        data.withUnsafeBufferPointer { p in
            var i = 0
            while i < p.count {
                let end = min(i + 5_552, p.count)    // the largest run before the sums can overflow
                while i < end {
                    a &+= UInt32(p[i])
                    b &+= a
                    i += 1
                }
                a %= 65_521
                b %= 65_521
            }
        }
        return (b << 16) | a
    }

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        let table = crcTable
        bytes.withUnsafeBufferPointer { p in
            for byte in p { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        }
        return c ^ 0xFFFF_FFFF
    }

    private static func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let typeBytes = Array(type.utf8)
        return bigEndian(UInt32(data.count)) + typeBytes + data + bigEndian(crc32(typeBytes + data))
    }

    private static func bigEndian(_ v: UInt32) -> [UInt8] {
        [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }
}
