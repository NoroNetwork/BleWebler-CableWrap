import Foundation

/// A 1-bit raster image of a label. `pixels[y][x] == true` means a black dot.
///
/// Width is the label length (along the paper feed); height is the print-head
/// dimension and must be a multiple of 8 (96 for the supported 12 mm heads).
struct LabelBitmap {
    let width: Int
    let height: Int
    var pixels: [[Bool]]   // [height][width]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: Array(repeating: false, count: width), count: height)
    }
}

/// Builds the byte packets the Marklife / Pristar / L13 printers expect.
///
/// Ported 1:1 from the web app's `marklife_p12.js`. Verified against real
/// hardware in the original project — keep the byte sequences identical.
enum MarklifeProtocol {

    /// Column-major, 8 rows per byte, with the Y axis inverted — exactly the
    /// encoding the firmware expects (see `bitmapToPacket` in the web app).
    static func encodeBitmap(_ bitmap: LabelBitmap) -> Data {
        let width = bitmap.width
        let height = bitmap.height
        var bytes = [UInt8]()
        bytes.reserveCapacity(width * (height / 8))

        for x in 0..<width {
            var y = 0
            while y < height {
                let invertedY = height - 8 - y
                var byte: UInt8 = 0
                for bit in 0..<8 {
                    let row = invertedY + bit
                    if row >= 0 && row < height && bitmap.pixels[row][x] {
                        byte |= (1 << bit)
                    }
                }
                bytes.append(byte)
                y += 8
            }
        }
        return Data(bytes)
    }

    /// The full ordered list of packets for one label.
    ///
    /// - Parameter segmentedPaper: `true` for die-cut / gapped labels, `false`
    ///   for continuous ("infinite") paper. Mirrors the web app's branch.
    static func printPackets(for bitmap: LabelBitmap, segmentedPaper: Bool) -> [Data] {
        let width = bitmap.width
        let payload = encodeBitmap(bitmap)

        var packets: [Data] = [
            Data([0x10, 0xff, 0x40]),                       // initialization
            Data(
                Array(repeating: 0x00, count: 15) +
                [0x10, 0xff, 0xf1, 0x02, 0x1d,
                 0x76,
                 0x30, 0x00,
                 0x0c, 0x00,
                 UInt8(width & 0xff), UInt8((width >> 8) & 0xff)]
            ),
            payload,
        ]

        if segmentedPaper {
            packets.append(contentsOf: [
                Data([0x1d, 0x0c, 0x10]),
                Data([0xff, 0xf1, 0x45]),
                Data([0x10, 0xff, 0x40]),
                Data([0x10, 0xff, 0x40]),
            ])
        } else {
            packets.append(contentsOf: [
                Data([0x1b, 0x4a, 0x5b]),                   // purge / feed
                Data([0x10, 0xff, 0xf1, 0x45]),             // end
            ])
        }
        return packets
    }

    /// Split a packet into BLE-sized chunks (96 bytes), matching the web app.
    static func chunked(_ data: Data, size: Int = 96) -> [Data] {
        guard data.count > size else { return [data] }
        var chunks = [Data]()
        var index = data.startIndex
        while index < data.endIndex {
            let end = data.index(index, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
            chunks.append(data.subdata(in: index..<end))
            index = end
        }
        return chunks
    }
}
