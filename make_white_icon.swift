import Cocoa

let svgPath = "/Users/tunahan/Desktop/leaf/Leaf/Resources/Assets.xcassets/Logo.imageset/icon.svg"
guard let svgImage = NSImage(contentsOfFile: svgPath) else {
    print("Cannot load SVG")
    exit(1)
}

let width: CGFloat = 1024
let height: CGFloat = 1024
let size = NSSize(width: width, height: height)

let newImage = NSImage(size: size)
newImage.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    print("No context")
    exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()

// Plain white background
context.setFillColor(CGColor.white)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Draw the SVG centered at ~600 width preserving aspect ratio
let originalSize = svgImage.size
let scale = min(600 / originalSize.width, 600 / originalSize.height)
let newWidth = originalSize.width * scale
let newHeight = originalSize.height * scale

let x = (width - newWidth) / 2
let y = (height - newHeight) / 2
let rect = NSRect(x: x, y: y, width: newWidth, height: newHeight)

context.interpolationQuality = .high
svgImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

newImage.unlockFocus()

guard let tiffData = newImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to convert image")
    exit(1)
}

let destPath = "/Users/tunahan/Desktop/leaf/Leaf/Resources/Assets.xcassets/AppIcon.appiconset/icon.png"

guard let cgImage = newImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    exit(1)
}

let finalContext = CGContext(data: nil,
                              width: Int(width),
                              height: Int(height),
                              bitsPerComponent: 8,
                              bytesPerRow: Int(width) * 4,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

finalContext.setFillColor(CGColor.white)
finalContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
finalContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

let finalImage = finalContext.makeImage()!
let url = URL(fileURLWithPath: destPath)
let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, finalImage, nil)
CGImageDestinationFinalize(destination)

print("White icon created!")
