import Cocoa
import CoreGraphics
import ImageIO

let path = "/Users/tunahan/Desktop/leaf/Leaf/Resources/Assets.xcassets/AppIcon.appiconset/icon.png"
guard let image = NSImage(contentsOfFile: path),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Failed to load image")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil,
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: width * 4,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    print("Failed to create context")
    exit(1)
}

context.setFillColor(CGColor.white)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

guard let newCgImage = context.makeImage() else {
    print("Failed to make target image")
    exit(1)
}

let url = URL(fileURLWithPath: path)
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
    print("Failed to create destination")
    exit(1)
}
CGImageDestinationAddImage(destination, newCgImage, nil)
if CGImageDestinationFinalize(destination) {
    print("Success")
} else {
    print("Failed to finalize image")
    exit(1)
}
