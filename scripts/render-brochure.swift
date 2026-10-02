import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Export the original brochure as sharp, zoomable pictures without changing its content.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("pdf/Tri State Fire & Security Systems Brochure.pdf")
guard let document = CGPDFDocument(source as CFURL) else { fatalError("Cannot read brochure") }
let output = root.appendingPathComponent("images/brochure-readable", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for number in 1...document.numberOfPages {
    guard let page = document.page(at: number) else { fatalError("Missing page") }
    let box = page.getBoxRect(.mediaBox)
    let width = 2400
    let scale = CGFloat(width) / box.width
    let height = Int(ceil(box.height * scale))
    guard let context = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Cannot render page") }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -box.minX, y: -box.minY)
    context.drawPDFPage(page)
    let target = output.appendingPathComponent("page-\(number).jpg")
    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { fatalError("Cannot save page") }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot finish page") }
    print("Page \(number): \(width) × \(height)")
}
