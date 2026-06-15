#!/usr/bin/swift
import AppKit

func drawIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // White background
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Rounded rect card
    let pad = s * 0.07
    let radius = s * 0.22
    let cardRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    ctx.setFillColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    let cardPath = CGMutablePath()
    cardPath.addRoundedRect(in: cardRect, cornerWidth: radius, cornerHeight: radius)
    ctx.addPath(cardPath)
    ctx.fillPath()

    // Node positions: triangle layout
    let cx = s * 0.5
    let cy = s * 0.5
    let spread = s * 0.26
    let positions: [CGPoint] = [
        CGPoint(x: cx,               y: cy - spread * 0.88),  // top (accent)
        CGPoint(x: cx - spread,      y: cy + spread * 0.55),  // bottom-left
        CGPoint(x: cx + spread,      y: cy + spread * 0.55),  // bottom-right
    ]

    let nodeR = s * 0.12
    let lw = max(1.5, s * 0.022)

    // Edges
    ctx.setStrokeColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.55)
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    let pairs = [(0,1),(1,2),(0,2)]
    for (a, b) in pairs {
        ctx.move(to: positions[a])
        ctx.addLine(to: positions[b])
    }
    ctx.strokePath()

    // Nodes
    for (i, pos) in positions.enumerated() {
        let rect = CGRect(x: pos.x - nodeR, y: pos.y - nodeR, width: nodeR*2, height: nodeR*2)
        // Fill
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fillEllipse(in: rect)
        // Border
        if i == 0 {
            ctx.setStrokeColor(red: 0.18, green: 0.38, blue: 1.0, alpha: 1)
            ctx.setLineWidth(lw * 1.6)
        } else {
            ctx.setStrokeColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.8)
            ctx.setLineWidth(lw * 1.2)
        }
        ctx.strokeEllipse(in: rect)
    }

    guard let cgImg = ctx.makeImage() else { return nil }
    let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: size, height: size))
    guard let tiff = nsImg.tiffRepresentation,
          let bmp = NSBitmapImageRep(data: tiff),
          let png = bmp.representation(using: .png, properties: [:]) else { return nil }
    return png
}

let entries: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let dir = "Connections.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

for (size, name) in entries {
    if let data = drawIcon(size: size) {
        fm.createFile(atPath: "\(dir)/\(name)", contents: data)
        print("  \(name)")
    }
}
print("Iconset ready.")
