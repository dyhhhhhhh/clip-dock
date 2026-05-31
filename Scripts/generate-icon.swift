#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let imagesDirectory = root.appendingPathComponent("Packaging/Assets/Images", isDirectory: true)
let outputDirectory = root.appendingPathComponent("Packaging/Assets/AppIcon.iconset", isDirectory: true)
let appIconSourceURL = imagesDirectory.appendingPathComponent("AppIconSource.png")
let menuBarIconSourceURL = imagesDirectory.appendingPathComponent("MenuBarIconSource.png")
let menuBarIconTemplateURL = imagesDirectory.appendingPathComponent("MenuBarIconTemplate.png")
let menuBarIconStatusURL = imagesDirectory.appendingPathComponent("MenuBarIconStatusTemplate.png")
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

let sourceAppIcon = NSImage(contentsOf: appIconSourceURL)

for image in images {
    let destination = outputDirectory.appendingPathComponent(image.filename)
    if let sourceAppIcon {
        let icon = try renderBitmap(from: sourceAppIcon, pixels: image.pixels, mode: .aspectFill)
        removeNearBlackBackground(from: icon)
        try writePNG(icon, to: destination)
    } else {
        let icon = drawIcon(size: image.pixels)
        try writePNG(icon, to: destination)
    }
}

if let sourceMenuBarIcon = NSImage(contentsOf: menuBarIconSourceURL) {
    let menuBarIcon = try renderBitmap(from: sourceMenuBarIcon, pixels: 512, mode: .aspectFit)
    makeTemplateImage(from: menuBarIcon)
    let fittedMenuBarIcon = try fitTemplateContent(from: menuBarIcon, pixels: 64, contentPixels: 58)
    try writePNG(fittedMenuBarIcon, to: menuBarIconTemplateURL)

    let statusMenuBarIcon = try fitTemplateContent(from: menuBarIcon, pixels: 36, contentPixels: 34)
    try writePNG(statusMenuBarIcon, to: menuBarIconStatusURL)
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

enum ImageRenderMode {
    case aspectFit
    case aspectFill
}

func renderBitmap(from image: NSImage, pixels: Int, mode: ImageRenderMode) throws -> NSBitmapImageRep {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0,
    ) else {
        throw NSError(domain: "ClipDockIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create icon bitmap"])
    }

    guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
        throw NSError(domain: "ClipDockIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create icon graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    context.imageInterpolation = .high
    image.draw(
        in: destinationRect(sourceSize: image.size, pixels: pixels, mode: mode),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1,
    )
    NSGraphicsContext.restoreGraphicsState()
    return representation
}

func destinationRect(sourceSize: NSSize, pixels: Int, mode: ImageRenderMode) -> NSRect {
    let target = CGFloat(pixels)
    guard sourceSize.width > 0, sourceSize.height > 0 else {
        return NSRect(x: 0, y: 0, width: target, height: target)
    }

    let scale: CGFloat = switch mode {
    case .aspectFit:
        min(target / sourceSize.width, target / sourceSize.height)
    case .aspectFill:
        max(target / sourceSize.width, target / sourceSize.height)
    }
    let width = sourceSize.width * scale
    let height = sourceSize.height * scale
    return NSRect(
        x: (target - width) / 2,
        y: (target - height) / 2,
        width: width,
        height: height,
    )
}

func removeNearBlackBackground(from representation: NSBitmapImageRep) {
    guard let data = representation.bitmapData else { return }
    let threshold: UInt8 = 8
    for y in 0 ..< representation.pixelsHigh {
        for x in 0 ..< representation.pixelsWide {
            let offset = y * representation.bytesPerRow + x * 4
            if data[offset] <= threshold, data[offset + 1] <= threshold, data[offset + 2] <= threshold {
                data[offset + 3] = 0
            }
        }
    }
}

func makeTemplateImage(from representation: NSBitmapImageRep) {
    guard let data = representation.bitmapData else { return }
    for y in 0 ..< representation.pixelsHigh {
        for x in 0 ..< representation.pixelsWide {
            let offset = y * representation.bytesPerRow + x * 4
            let red = Double(data[offset])
            let green = Double(data[offset + 1])
            let blue = Double(data[offset + 2])
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let alpha: UInt8
            if luminance >= 190 {
                alpha = 0
            } else if luminance <= 90 {
                alpha = 255
            } else {
                alpha = UInt8(max(0, min(255, ((190 - luminance) / 100) * 255)))
            }
            data[offset] = 0
            data[offset + 1] = 0
            data[offset + 2] = 0
            data[offset + 3] = min(data[offset + 3], alpha)
        }
    }
}

func fitTemplateContent(from representation: NSBitmapImageRep, pixels: Int, contentPixels: Int) throws -> NSBitmapImageRep {
    guard let sourceData = representation.bitmapData else { return representation }
    guard let bounds = visibleBounds(in: representation) else { return representation }
    let targetContentPixels = min(max(contentPixels, 1), pixels)
    guard let fitted = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0,
    ),
    let fittedData = fitted.bitmapData
    else {
        throw NSError(domain: "ClipDockIcon", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to fit menu bar icon"])
    }

    for offset in 0 ..< (fitted.bytesPerRow * fitted.pixelsHigh) {
        fittedData[offset] = 0
    }

    let sourceWidth = bounds.maxX - bounds.minX + 1
    let sourceHeight = bounds.maxY - bounds.minY + 1
    let scale = min(Double(targetContentPixels) / Double(sourceWidth), Double(targetContentPixels) / Double(sourceHeight))
    let destinationWidth = max(1, Int(round(Double(sourceWidth) * scale)))
    let destinationHeight = max(1, Int(round(Double(sourceHeight) * scale)))
    let destinationX = (pixels - destinationWidth) / 2
    let destinationY = (pixels - destinationHeight) / 2

    for y in 0 ..< destinationHeight {
        for x in 0 ..< destinationWidth {
            let destinationOffset = (destinationY + y) * fitted.bytesPerRow + (destinationX + x) * 4
            fittedData[destinationOffset] = 0
            fittedData[destinationOffset + 1] = 0
            fittedData[destinationOffset + 2] = 0
            fittedData[destinationOffset + 3] = interpolatedAlpha(
                in: sourceData,
                bytesPerRow: representation.bytesPerRow,
                bounds: bounds,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                destinationX: x,
                destinationY: y,
                destinationWidth: destinationWidth,
                destinationHeight: destinationHeight,
            )
        }
    }

    return fitted
}

func interpolatedAlpha(
    in data: UnsafeMutablePointer<UInt8>,
    bytesPerRow: Int,
    bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int),
    sourceWidth: Int,
    sourceHeight: Int,
    destinationX: Int,
    destinationY: Int,
    destinationWidth: Int,
    destinationHeight: Int,
) -> UInt8 {
    let sampleX = Double(bounds.minX) + ((Double(destinationX) + 0.5) / Double(destinationWidth)) * Double(sourceWidth) - 0.5
    let sampleY = Double(bounds.minY) + ((Double(destinationY) + 0.5) / Double(destinationHeight)) * Double(sourceHeight) - 0.5
    let x0 = max(bounds.minX, min(bounds.maxX, Int(floor(sampleX))))
    let y0 = max(bounds.minY, min(bounds.maxY, Int(floor(sampleY))))
    let x1 = min(bounds.maxX, x0 + 1)
    let y1 = min(bounds.maxY, y0 + 1)
    let xWeight = max(0, min(1, sampleX - Double(x0)))
    let yWeight = max(0, min(1, sampleY - Double(y0)))

    func alpha(x: Int, y: Int) -> Double {
        Double(data[y * bytesPerRow + x * 4 + 3])
    }

    let top = alpha(x: x0, y: y0) * (1 - xWeight) + alpha(x: x1, y: y0) * xWeight
    let bottom = alpha(x: x0, y: y1) * (1 - xWeight) + alpha(x: x1, y: y1) * xWeight
    let value = top * (1 - yWeight) + bottom * yWeight
    return UInt8(max(0, min(255, value.rounded())))
}

func visibleBounds(in representation: NSBitmapImageRep) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
    guard let data = representation.bitmapData else { return nil }
    var minX = representation.pixelsWide
    var minY = representation.pixelsHigh
    var maxX = -1
    var maxY = -1

    for y in 0 ..< representation.pixelsHigh {
        for x in 0 ..< representation.pixelsWide {
            let offset = y * representation.bytesPerRow + x * 4
            guard data[offset + 3] > 64 else { continue }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard maxX >= minX, maxY >= minY else { return nil }
    return (minX, minY, maxX, maxY)
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

func writePNG(_ representation: NSBitmapImageRep, to url: URL) throws {
    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ClipDockIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to encode icon PNG"])
    }
    try data.write(to: url, options: [.atomic])
}
