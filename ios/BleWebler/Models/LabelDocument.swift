import SwiftUI

enum LabelMode: String, CaseIterable, Identifiable {
    case text, cable, qr
    var id: String { rawValue }
    var title: String {
        switch self {
        case .text: return "Text"
        case .cable: return "Cable"
        case .qr: return "QR"
        }
    }
    var systemImage: String {
        switch self {
        case .text: return "textformat"
        case .cable: return "cable.connector"
        case .qr: return "qrcode"
        }
    }
}

enum CableStyle: String, CaseIterable, Identifiable {
    case flag, repeating
    var id: String { rawValue }
    var title: String {
        switch self {
        case .flag: return "Flag (both sides)"
        case .repeating: return "Repeating"
        }
    }
}

enum LabelTextAlign: String, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    var systemImage: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
}

/// All editable state for the current label.
@MainActor
final class LabelDocument: ObservableObject {
    // Paper / printer
    @Published var paperWidthMm: Double = 40
    @Published var infinitePaper: Bool = false
    /// Die-cut (gapped) labels vs continuous roll. Maps to the protocol branch.
    @Published var segmentedPaper: Bool = true
    @Published var copies: Int = 1

    // Head characteristics (overridden when a printer connects)
    @Published var headHeightPx: Int = 96
    @Published var dotsPerMm: Int = 8

    // Mode
    @Published var mode: LabelMode = .text

    // Text mode
    @Published var text: String = "Label"
    @Published var bold: Bool = false
    @Published var align: LabelTextAlign = .center

    // Cable mode
    @Published var cableStyle: CableStyle = .flag
    @Published var cableText: String = "CABLE-01"
    @Published var cableDiameterMm: Double = 5
    @Published var cableFlagLengthMm: Double = 20
    @Published var cableSpacingMm: Double = 6

    // QR mode
    @Published var qrText: String = "https://example.com"

    func applyModel(_ model: SupportedPrinter?) {
        guard let model else { return }
        headHeightPx = model.widthPx
        dotsPerMm = model.dotsPerMm
    }

    /// Label length in pixels for the current mode.
    var labelWidthPx: Int {
        let dpm = Double(dotsPerMm)
        switch mode {
        case .cable where cableStyle == .flag:
            let wrap = Double.pi * cableDiameterMm * dpm
            let flag = cableFlagLengthMm * dpm
            return max(8, Int((flag * 2 + wrap).rounded()))
        default:
            return max(8, Int((paperWidthMm * dpm).rounded()))
        }
    }

    var headHeightPxRoundedTo8: Int {
        let h = headHeightPx
        return h % 8 == 0 ? h : ((h / 8) + 1) * 8
    }
}
