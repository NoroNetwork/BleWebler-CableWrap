import SwiftUI
import UIKit

/// Converts the SwiftUI label into a 1-bit `LabelBitmap` at the printer's exact
/// pixel resolution. Mirrors the web app's `constructBitmap`: a pixel becomes
/// black when its average luminance is below the mid-point.
enum LabelRasterizer {

    @MainActor
    static func rasterize(_ doc: LabelDocument) -> LabelBitmap {
        let width = doc.labelWidthPx
        let height = doc.headHeightPxRoundedTo8

        let view = LabelContentView(doc: doc, widthPx: CGFloat(width), heightPx: CGFloat(height))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = true

        guard let cg = renderer.cgImage else {
            return LabelBitmap(width: width, height: height)
        }
        return bitmap(from: cg, width: width, height: height)
    }

    /// Read the rendered CGImage into a black/white grid.
    private static func bitmap(from cg: CGImage, width: Int, height: Int) -> LabelBitmap {
        var result = LabelBitmap(width: width, height: height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 255, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixelData,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return result }

        // White background so transparent areas read as "no dot".
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * bytesPerPixel
                let avg = (Int(pixelData[i]) + Int(pixelData[i + 1]) + Int(pixelData[i + 2])) / 3
                result.pixels[y][x] = avg < 128   // dark → black dot
            }
        }
        return result
    }
}
