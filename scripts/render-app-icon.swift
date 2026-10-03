#!/usr/bin/env swift
// Renders the Spendly emblem (docs/brand/spendly.svg) into the three App Icon variants.
//
//     swift scripts/render-app-icon.swift
//
// The emblem's two paths use only M/L/C/Z with absolute coordinates, so a tiny parser is enough.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let emblemPaths = [
    "M137 64 L402 2 C443 -8 480 19 480 60 L480 277 C480 296 467 307 449 301 L307 255 C293 250 289 242 289 229 L289 226 C289 215 284 210 273 206 L134 159 C118 154 110 144 110 129 L110 94 C110 79 120 68 137 64 Z",
    "M48 171 L216 229 C232 234 236 244 236 258 L236 263 C236 276 244 284 256 288 L448 351 C470 358 480 370 480 391 L480 396 C480 434 452 456 414 450 L50 389 C17 384 0 362 0 328 L0 204 C0 180 25 162 48 171 Z",
]
let viewBox = CGSize(width: 480, height: 452)

func cgPath(_ data: String) -> CGPath {
    let path = CGMutablePath()
    // Split "M137 64 L402 2" into ["M", "137", "64", "L", "402", "2"]: letters are separate tokens.
    let spaced = data.replacingOccurrences(of: "([MLCZ])", with: " $1 ", options: .regularExpression)
    var tokens = spaced.split(separator: " ").map(String.init)[...]
    func number() -> CGFloat { CGFloat(Double(tokens.removeFirst())!) }
    var command = ""
    while !tokens.isEmpty {
        if let first = tokens.first, first.first!.isLetter {
            command = tokens.removeFirst()
        }
        switch command {
        case "M": path.move(to: CGPoint(x: number(), y: number()))
        case "L": path.addLine(to: CGPoint(x: number(), y: number()))
        case "C":
            let c1 = CGPoint(x: number(), y: number())
            let c2 = CGPoint(x: number(), y: number())
            path.addCurve(to: CGPoint(x: number(), y: number()), control1: c1, control2: c2)
        case "Z": path.closeSubpath()
        default: fatalError("unsupported command \(command)")
        }
    }
    return path
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// `background: nil` leaves the canvas transparent (dark and tinted variants).
func render(to url: URL, background: CGColor?, emblem: CGColor, size: Int = 1024) {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let side = CGFloat(size)
    if let background {
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }

    // Emblem fills ~58% of the width, optically centered.
    let scale = side * 0.58 / viewBox.width
    let drawn = CGSize(width: viewBox.width * scale, height: viewBox.height * scale)
    context.translateBy(x: (side - drawn.width) / 2, y: (side + drawn.height) / 2)
    context.scaleBy(x: scale, y: -scale) // SVG's y axis points down
    context.setFillColor(emblem)
    for data in emblemPaths {
        context.addPath(cgPath(data))
        context.fillPath()
    }

    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

let iconSet = URL(fileURLWithPath: "Spendly/Assets.xcassets/AppIcon.appiconset")
let brandRed: UInt32 = 0xFF4D2E
render(to: iconSet.appendingPathComponent("AppIcon.png"), background: color(0x131417), emblem: color(brandRed))
render(to: iconSet.appendingPathComponent("AppIcon-Dark.png"), background: nil, emblem: color(brandRed))
render(to: iconSet.appendingPathComponent("AppIcon-Tinted.png"), background: nil, emblem: color(0xFFFFFF))
print("rendered 3 icon variants into \(iconSet.path)")
