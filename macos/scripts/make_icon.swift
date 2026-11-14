// Icône AZA — anneau et onde dithérés (charte Robōtariis).
// Rendu en basse résolution (128×128) puis agrandi au plus proche (×8),
// Usage : swift make_icon.swift sortie.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let N = 128, scale = 8, S = N * scale
let bayer: [[Double]] = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

func noise(_ x: Int, _ y: Int) -> Double {
    var h = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263)
    h = (h ^ (h >> 13)) &* 1_274_126_177
    return Double((h ^ (h >> 16)) & 0xFFFF) / 65535.0
}

func threshold(_ x: Int, _ y: Int) -> Double {
    0.55 * (bayer[y % 4][x % 4] + 0.5) / 16 + 0.45 * noise(x, y)
}

typealias RGB = (Double, Double, Double)
let bg: RGB = (0x0A / 255.0, 0x0A / 255.0, 0x0A / 255.0)
let ink: RGB = (0xF2 / 255.0, 0xF2 / 255.0, 0xF2 / 255.0)
let orange: RGB = (0xF9 / 255.0, 0x73 / 255.0, 0x16 / 255.0)

var low = [RGB?](repeating: nil, count: N * N)  // nil = transparent (hors squircle)
let c = Double(N) / 2

for y in 0..<N {
    for x in 0..<N {
        let px = (Double(x) + 0.5 - c) / (c * 0.80)
        let py = (Double(y) + 0.5 - c) / (c * 0.80)
        if pow(abs(px), 5) + pow(abs(py), 5) > 1 { continue }

        var col = bg
        let dx = Double(x) + 0.5 - c, dy = Double(y) + 0.5 - c
        let r = sqrt(dx * dx + dy * dy) / (c * 0.62)

        // Anneau orange, bord dithéré des deux côtés
        let ring = max(0, 1 - abs(r - 0.86) / 0.16)
        if ring * 1.25 > threshold(x, y) { col = orange }
        // Halo intérieur, très léger
        if r < 0.70 && 0.18 * (1 - r) > threshold(x, y) {
            col = (bg.0 + orange.0 * 0.5, bg.1 + orange.1 * 0.5, bg.2 + orange.2 * 0.5)
        }

        // Onde : sinus amorti, trait blanc de 2 px dans le disque
        if r < 0.72 {
            let t = dx / (c * 0.55)
            let wave = sin(t * 3.2 * Double.pi) * exp(-t * t * 1.6) * c * 0.30
            if abs(dy - wave) < 2.2 { col = ink }
        }
        low[y * N + x] = col
    }
}
// Agrandissement au plus proche
var pixels = [UInt8](repeating: 0, count: S * S * 4)
for y in 0..<S {
    for x in 0..<S {
        guard let p = low[(y / scale) * N + (x / scale)] else { continue }
        let i = (y * S + x) * 4
        pixels[i] = UInt8(min(255, p.0 * 255))
        pixels[i + 1] = UInt8(min(255, p.1 * 255))
        pixels[i + 2] = UInt8(min(255, p.2 * 255))
        pixels[i + 3] = 255
    }
}

let ctx = CGContext(data: &pixels, width: S, height: S, bitsPerComponent: 8, bytesPerRow: S * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let image = ctx.makeImage()!
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("icône : \(out.path)")
