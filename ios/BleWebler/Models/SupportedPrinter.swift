import Foundation
import CoreBluetooth

/// Static description of a printer family we know how to drive.
///
/// Ported from the web app's `printers_supported.js`. All currently supported
/// models share the same Marklife BLE protocol and 203 dpi (8 dots/mm) head.
struct SupportedPrinter: Identifiable {
    let id = UUID()
    let name: String
    /// Advertised BLE name prefix used to recognise the device (e.g. "P12_").
    let namePrefix: String
    /// Printed width of the head, in pixels (12 mm @ 203 dpi = 96 px).
    let widthPx: Int
    /// Dots per millimetre (203 dpi ≈ 8).
    let dotsPerMm: Int
    let info: String

    static let all: [SupportedPrinter] = [
        SupportedPrinter(
            name: "Marklife P12", namePrefix: "P12_", widthPx: 96, dotsPerMm: 8,
            info: "Marklife P12 · 203 dpi · 12 mm print width · 15 mm paper · Bluetooth 4.0 (BLE)"
        ),
        SupportedPrinter(
            name: "Marklife P15", namePrefix: "P15_", widthPx: 96, dotsPerMm: 8,
            info: "Marklife P15 · 203 dpi · 12 mm print width · 15 mm paper · Bluetooth 4.0 (BLE)"
        ),
        SupportedPrinter(
            name: "Pristar P15", namePrefix: "P15R_", widthPx: 96, dotsPerMm: 8,
            info: "Pristar P15 · 203 dpi · 12 mm print width · 15 mm paper · Bluetooth 4.0 (BLE)"
        ),
        SupportedPrinter(
            name: "L13 (SilverCrest and others)", namePrefix: "L13_", widthPx: 96, dotsPerMm: 8,
            info: "L13 · 203 dpi · 12 mm print width · 15 mm paper · Bluetooth 4.0 (BLE)"
        ),
    ]

    /// Match a discovered peripheral name (e.g. "P15_1234_BLE") to a family.
    static func match(name: String?) -> SupportedPrinter? {
        guard let name else { return nil }
        return all.first { name.hasPrefix($0.namePrefix) }
    }
}

/// BLE service / characteristic UUIDs used by the Marklife protocol.
enum PrinterGATT {
    static let printService = CBUUID(string: "FF00")
    static let printCharacteristic = CBUUID(string: "FF02")

    // ISSC service used for reading device info (battery, firmware, …).
    static let infoService = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
    static let infoWrite = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    static let infoNotify = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
}
