import AppKit
import ImageIO

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func chunk(_ type: String, _ payload: Data) -> Data {
    var length = UInt32(payload.count + 8).bigEndian
    var result = Data(type.utf8)
    withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
    result.append(payload)
    return result
}

var representations = Data()

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let side = CGFloat(pixels)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let inset = side * 0.045
        let background = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2),
                                      xRadius: side * 0.225, yRadius: side * 0.225)
        NSGradient(starting: NSColor(red: 0.24, green: 0.65, blue: 0.52, alpha: 1),
                   ending: NSColor(red: 0.09, green: 0.36, blue: 0.31, alpha: 1))!.draw(in: background, angle: -45)
        NSColor.white.withAlphaComponent(0.94).setFill()
        for (index, fraction) in [0.34, 0.58, 0.42].enumerated() {
            let length = side * fraction
            let height = side * 0.075
            let bar = NSBezierPath(roundedRect: NSRect(x: side * 0.79 - length, y: side * (0.30 + Double(index) * 0.175), width: length, height: height),
                                   xRadius: height / 2, yRadius: height / 2)
            bar.fill()
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        let png = bitmap.representation(using: .png, properties: [:])!
        try png.write(to: destination.appendingPathComponent(name))
        let type: String
        switch (points, scale) {
        case (16, 1): type = "icp4"
        case (16, 2): type = "ic11"
        case (32, 1): type = "icp5"
        case (32, 2): type = "ic12"
        case (128, 1): type = "ic07"
        case (128, 2): type = "ic13"
        case (256, 1): type = "ic08"
        case (256, 2): type = "ic14"
        case (512, 1): type = "ic09"
        default: type = "ic10"
        }
        representations.append(chunk(type, png))
    }
}

// Encode the standard ICNS container directly; iconutil's conversion service is unavailable in some restricted runtimes.
let icns = chunk("icns", representations)
guard let source = CGImageSourceCreateWithData(icns as CFData, nil), CGImageSourceGetCount(source) == 10,
      (0..<10).allSatisfy({ CGImageSourceCreateImageAtIndex(source, $0, nil) != nil }) else {
    fatalError("Generated ICNS failed native decoding validation")
}
try icns.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
