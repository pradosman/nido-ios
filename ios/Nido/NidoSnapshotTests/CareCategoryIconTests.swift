import SwiftUI
import XCTest

@testable import Nido

@MainActor
final class CareCategoryIconTests: XCTestCase {
    func testDiaperGlyphIsVisuallyDistinctFromItsShortcutDropletFallback() throws {
        let tint = Color.black
        let comparison = HStack(spacing: 0) {
            CareCategoryIcon(category: .diaper, size: 48, tint: tint)
                .frame(width: 64, height: 64)
            Image(systemName: CareCategory.diaper.shortcutSystemImageName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
        }
        .frame(width: 128, height: 64)
        .background(Color.white)
        let hosting = UIHostingController(rootView: comparison)
        hosting.view.frame = CGRect(x: 0, y: 0, width: 128, height: 64)
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: hosting.view.bounds.size, format: format).image { _ in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }

        let attachment = XCTAttachment(image: image)
        attachment.name = "Custom diaper glyph compared with the Shortcuts drop fallback"
        attachment.lifetime = .keepAlways
        add(attachment)

        let cgImage = try XCTUnwrap(image.cgImage)
        let pixels = try rgbaPixels(cgImage)
        let scale = 3
        let slotWidth = 64 * scale
        let height = 64 * scale
        let custom = foregroundMask(pixels, imageWidth: cgImage.width, xOffset: 0, width: slotWidth, height: height)
        let fallback = foregroundMask(pixels, imageWidth: cgImage.width, xOffset: slotWidth, width: slotWidth, height: height)
        let union = zip(custom, fallback).filter { $0 || $1 }.count
        let intersection = zip(custom, fallback).filter { $0 && $1 }.count
        let overlap = CGFloat(intersection) / CGFloat(union)

        XCTAssertGreaterThan(union, 500, "Both icon renders must contain enough foreground pixels to compare.")
        XCTAssertLessThan(overlap, 0.85, "The diaper must render its custom garment shape, not the (CareCategory.diaper.shortcutSystemImageName) fallback.")
    }

    private func rgbaPixels(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private func foregroundMask(
        _ pixels: [UInt8],
        imageWidth: Int,
        xOffset: Int,
        width: Int,
        height: Int
    ) -> [Bool] {
        (0..<height).flatMap { y in
            (0..<width).map { x in
                let offset = (y * imageWidth + xOffset + x) * 4
                return pixels[offset] < 96 && pixels[offset + 1] < 96 && pixels[offset + 2] < 96
            }
        }
    }
}
