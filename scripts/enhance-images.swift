#!/usr/bin/env swift
// Non-generative image enhancement using macOS Core Image and ImageIO.
// Run from the project root: swift scripts/enhance-images.swift
import Foundation
import CoreImage
import ImageIO
import CryptoKit

struct Variant: Codable {
    let path: String
    let avif: String
    let width: Int
    let height: Int
}
struct Asset: Codable {
    let source: String
    let sourceSHA256: String
    let sourceWidth: Int
    let sourceHeight: Int
    let variants: [Variant]
}

enum EnhancementError: Error { case failed(String) }
let fileManager = FileManager.default
let project = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let outputDirectory = project.appendingPathComponent("images/enhanced")
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
let htmlFiles = try fileManager.contentsOfDirectory(at: project, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "html" }.sorted { $0.path < $1.path }
// Only process raster assets actually referenced by the current site.
let pattern = try NSRegularExpression(pattern: #"(?:src|poster|href)="(/images/[^"?]+\.(?:jpe?g|png))""#, options: [.caseInsensitive])
var paths = Set<String>()
let priorManifest = outputDirectory.appendingPathComponent("manifest.json")
// Once HTML references the derivatives, use the manifest to reprocess originals.
if fileManager.fileExists(atPath: priorManifest.path) {
    let old = try JSONDecoder().decode([Asset].self, from: Data(contentsOf: priorManifest))
    old.forEach { paths.insert($0.source) }
}
for file in htmlFiles {
    let contents = try String(contentsOf: file, encoding: .utf8)
    for match in pattern.matches(in: contents, range: NSRange(contents.startIndex..., in: contents)) {
        guard let range = Range(match.range(at: 1), in: contents) else { continue }
        let path = String(contents[range]).dropFirst()
        if !path.hasPrefix("images/enhanced/") { paths.insert(String(path)) }
    }
}
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
var manifest = [Asset]()

func encode(_ image: CGImage, to url: URL, type: String, quality: Double) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
        throw EnhancementError.failed("Cannot create \(url.path)")
    }
    let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: quality,
        kCGImagePropertyOrientation: 1
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw EnhancementError.failed("Cannot encode \(url.path)")
    }
}

for path in paths.sorted() {
    try autoreleasepool {
        let sourceURL = project.appendingPathComponent(path)
        let sourceData = try Data(contentsOf: sourceURL)
        guard let decoder = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(decoder, 0, nil) else {
            throw EnhancementError.failed("Cannot read \(path)")
        }
        let original = CIImage(cgImage: cgImage)
        let width = cgImage.width, height = cgImage.height
        let longest = max(width, height)
        let filename = sourceURL.lastPathComponent
        let isBrochure = filename.hasPrefix("brochure_page_")
        let isLogo = filename == "tristate_logo.jpg"
        let isIcon = filename == "tristate_icon.jpg"
        // Brochure masters remain readable when opened full-size. Photo masters
        // cover the site's largest boxes on displays with high pixel density.
        let targetLongest = isBrochure ? longest * 2 : isLogo ? longest : isIcon ? 768 : 1920
        let targets = isLogo ? [320, 640, targetLongest] : isIcon ? [384, targetLongest] : isBrochure ? [922, 1844, targetLongest] : [480, 960, targetLongest]
        let outputExtension = sourceURL.pathExtension.lowercased() == "png" ? "png" : "jpg"
        let base = sourceURL.deletingPathExtension().lastPathComponent
        var variants = [Variant]()
        for edge in Set(targets).sorted() {
            let scale = Double(edge) / Double(longest)
            let targetWidth = max(1, Int((Double(width) * scale).rounded()))
            let targetHeight = max(1, Int((Double(height) * scale).rounded()))
            let extent = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
            // Lanczos interpolation preserves the original composition and color.
            // Unsharp masking enhances existing edges; it adds no generated detail.
            let resized = original.clampedToExtent().applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1.0
            ]).cropped(to: extent)
            let enhanced = resized.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 0.75,
                kCIInputIntensityKey: isBrochure || isLogo || isIcon ? 0.14 : 0.26
            ]).cropped(to: extent)
            guard let rendered = context.createCGImage(enhanced, from: extent, format: .RGBA8, colorSpace: colorSpace) else {
                throw EnhancementError.failed("Cannot render \(path)")
            }
            let stem = "\(base)-\(targetWidth)w"
            let fallbackPath = "images/enhanced/\(stem).\(outputExtension)"
            let avifPath = "images/enhanced/\(stem).avif"
            try encode(rendered, to: project.appendingPathComponent(fallbackPath), type: outputExtension == "png" ? "public.png" : "public.jpeg", quality: 0.97)
            try encode(rendered, to: project.appendingPathComponent(avifPath), type: "public.avif", quality: 0.93)
            variants.append(Variant(path: fallbackPath, avif: avifPath, width: targetWidth, height: targetHeight))
        }
        let hash = SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined()
        manifest.append(Asset(source: path, sourceSHA256: hash, sourceWidth: width, sourceHeight: height, variants: variants))
        let largest = variants.last!
        print("\(filename): \(width)×\(height) → \(largest.width)×\(largest.height)")
        fflush(stdout)
    }
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(manifest).write(to: priorManifest, options: .atomic)
print("Enhanced \(manifest.count) original assets; originals preserved.")
