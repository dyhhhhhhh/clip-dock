#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("Packaging/Assets/AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: outputDirectory)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

struct IconImage {
    let filename: String
    let pixels: Int
}

let images = [
    IconImage(filename: "icon_16x16.png", pixels: 16),
    IconImage(filename: "icon_16x16@2x.png", pixels: 32),
    IconImage(filename: "icon_32x32.png", pixels: 32),
    IconImage(filename: "icon_32x32@2x.png", pixels: 64),
    IconImage(filename: "icon_128x128.png", pixels: 128),
    IconImage(filename: "icon_128x128@2x.png", pixels: 256),
    IconImage(filename: "icon_256x256.png", pixels: 256),
    IconImage(filename: "icon_256x256@2x.png", pixels: 512),
    IconImage(filename: "icon_512x512.png", pixels: 512),
    IconImage(filename: "icon_512x512@2x.png", pixels: 1024),
]

for image in images {
    let icon = drawIcon(size: image.pixels)
    let destination = outputDirectory.appendingPathComponent(image.filename)
    try writePNG(icon, to: destination)
}

func drawIcon(size: Int) -> NSImage {
    let canvas = NSSize(width: size, height: size)
    let image = NSImage(size: canvas)
    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = NSRect(origin: .zero, size: canvas)
    NSColor(calibratedRed: 0.004, green: 0.004, blue: 0.008, alpha: 1).setFill()
    bounds.fill()

    let radius = CGFloat(size) * 0.22
    let tileInset = CGFloat(size) * 0.11
    let tileRect = bounds.insetBy(dx: tileInset, dy: tileInset)
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.059, green: 0.063, blue: 0.067, alpha: 1).setFill()
    tilePath.fill()
    NSColor(calibratedRed: 0.369, green: 0.416, blue: 0.824, alpha: 1).setStroke()
    tilePath.lineWidth = max(1, CGFloat(size) * 0.018)
    tilePath.stroke()

    let clipRect = NSRect(
        x: CGFloat(size) * 0.31,
        y: CGFloat(size) * 0.24,
        width: CGFloat(size) * 0.38,
        height: CGFloat(size) * 0.48,
    )
    let board = NSBezierPath(roundedRect: clipRect, xRadius: CGFloat(size) * 0.055, yRadius: CGFloat(size) * 0.055)
    NSColor(calibratedRed: 0.969, green: 0.973, blue: 0.973, alpha: 1).setFill()
    board.fill()

    let top = NSRect(
        x: CGFloat(size) * 0.39,
        y: CGFloat(size) * 0.65,
        width: CGFloat(size) * 0.22,
        height: CGFloat(size) * 0.09,
    )
    let topPath = NSBezierPath(roundedRect: top, xRadius: CGFloat(size) * 0.035, yRadius: CGFloat(size) * 0.035)
    NSColor(calibratedRed: 0.369, green: 0.416, blue: 0.824, alpha: 1).setFill()
    topPath.fill()

    NSColor(calibratedRed: 0.369, green: 0.416, blue: 0.824, alpha: 1).setStroke()
    for index in 0 ..< 3 {
        let y = CGFloat(size) * (0.53 - CGFloat(index) * 0.105)
        let line = NSBezierPath()
        line.move(to: NSPoint(x: CGFloat(size) * 0.39, y: y))
        line.line(to: NSPoint(x: CGFloat(size) * 0.61, y: y))
        line.lineWidth = max(1, CGFloat(size) * 0.024)
        line.lineCapStyle = .round
        line.stroke()
    }

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: tiff),
          let data = representation.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ClipDockIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to render icon PNG"])
    }
    try data.write(to: url, options: [.atomic])
}
