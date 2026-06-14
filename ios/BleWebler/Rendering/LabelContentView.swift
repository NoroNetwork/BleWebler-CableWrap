import SwiftUI

/// Renders the label content at an exact pixel size (points == pixels when the
/// rasterizer uses scale 1). The same view is used for on-screen preview and
/// for rasterization, so what you see is what prints.
struct LabelContentView: View {
    @ObservedObject var doc: LabelDocument
    let widthPx: CGFloat
    let heightPx: CGFloat

    private var fontSize: CGFloat { heightPx * 0.7 }

    var body: some View {
        ZStack {
            Color.white
            content
        }
        .frame(width: widthPx, height: heightPx)
        .clipped()
    }

    @ViewBuilder private var content: some View {
        switch doc.mode {
        case .text: textContent
        case .cable: cableContent
        case .qr: qrContent
        }
    }

    // MARK: Text

    private var textContent: some View {
        Text(doc.text.isEmpty ? " " : doc.text)
            .font(.system(size: fontSize, weight: doc.bold ? .bold : .regular))
            .foregroundColor(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.05)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: doc.align.alignment)
            .padding(.horizontal, 4)
    }

    // MARK: Cable

    @ViewBuilder private var cableContent: some View {
        switch doc.cableStyle {
        case .flag: cableFlag
        case .repeating: cableRepeat
        }
    }

    private var cableFlag: some View {
        let dpm = CGFloat(doc.dotsPerMm)
        let flag = CGFloat(doc.cableFlagLengthMm) * dpm
        let wrap = CGFloat.pi * CGFloat(doc.cableDiameterMm) * dpm
        return HStack(spacing: 0) {
            flagText(angle: 0).frame(width: flag)
            Color.white.frame(width: wrap)   // bare wrap zone around the cable
            flagText(angle: 180).frame(width: flag)
        }
    }

    private func flagText(angle: Double) -> some View {
        Text(doc.cableText.isEmpty ? " " : doc.cableText)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.05)
            .rotationEffect(.degrees(angle))
    }

    private var cableRepeat: some View {
        let spacing = CGFloat(doc.cableSpacingMm) * CGFloat(doc.dotsPerMm)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let label = doc.cableText.isEmpty ? " " : doc.cableText
        let tileW = (label as NSString).size(withAttributes: [.font: font]).width
        let count = max(1, Int(((widthPx + spacing) / (tileW + spacing)).rounded(.down)))
        return HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in
                Text(doc.cableText.isEmpty ? " " : doc.cableText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: QR

    @ViewBuilder private var qrContent: some View {
        if let img = QRGenerator.image(from: doc.qrText.isEmpty ? " " : doc.qrText) {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(2)
        } else {
            Text("QR error").foregroundColor(.black)
        }
    }
}
