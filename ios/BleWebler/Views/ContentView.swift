import SwiftUI

struct ContentView: View {
    @EnvironmentObject var printer: PrinterManager
    @EnvironmentObject var doc: LabelDocument

    @State private var showPrinterSheet = false
    @State private var showSettings = false
    @State private var isPrinting = false
    @State private var alertMessage: String?

    private let previewHeight: CGFloat = 96

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    previewCard
                    modePicker
                    modeControls
                    printSection
                }
                .padding()
            }
            .navigationTitle("BleWebler")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { connectionButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showPrinterSheet) { PrinterView() }
            .sheet(isPresented: $showSettings) { PaperSettingsView() }
            .alert("Print", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .onChange(of: printer.connectionState) { _ in
                doc.applyModel(printer.connectedModel)
            }
        }
    }

    // MARK: Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview").font(.headline)
            let w = CGFloat(doc.labelWidthPx)
            let h = CGFloat(doc.headHeightPxRoundedTo8)
            let scale = previewHeight / h
            ScrollView(.horizontal, showsIndicators: true) {
                LabelContentView(doc: doc, widthPx: w, heightPx: h)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: w * scale, height: previewHeight)
            }
            .frame(height: previewHeight)
            .background(Color(.systemGray6))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(String(format: "%.0f mm × %.0f mm  ·  %d × %d px",
                        Double(doc.labelWidthPx) / Double(doc.dotsPerMm),
                        Double(doc.headHeightPxRoundedTo8) / Double(doc.dotsPerMm),
                        doc.labelWidthPx, doc.headHeightPxRoundedTo8))
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Mode

    private var modePicker: some View {
        Picker("Mode", selection: $doc.mode) {
            ForEach(LabelMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder private var modeControls: some View {
        switch doc.mode {
        case .text: textControls
        case .cable: cableControls
        case .qr: qrControls
        }
    }

    private var textControls: some View {
        GroupBox("Text") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Label text", text: $doc.text)
                    .textFieldStyle(.roundedBorder)
                Toggle("Bold", isOn: $doc.bold)
                Picker("Alignment", selection: $doc.align) {
                    ForEach(LabelTextAlign.allCases) { a in
                        Image(systemName: a.systemImage).tag(a)
                    }
                }
                .pickerStyle(.segmented)
            }.padding(.vertical, 4)
        }
    }

    private var cableControls: some View {
        GroupBox("Cable Wrap") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Cable text", text: $doc.cableText)
                    .textFieldStyle(.roundedBorder)
                Picker("Style", selection: $doc.cableStyle) {
                    ForEach(CableStyle.allCases) { s in Text(s.title).tag(s) }
                }
                .pickerStyle(.segmented)

                if doc.cableStyle == .flag {
                    stepperRow("Cable diameter", value: $doc.cableDiameterMm,
                               range: 0.5...50, step: 0.5, unit: "mm")
                    stepperRow("Flag length", value: $doc.cableFlagLengthMm,
                               range: 3...100, step: 1, unit: "mm")
                    Text("Wrap zone = π × diameter. Far end is rotated 180° so it reads upright on both faces when folded.")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    stepperRow("Spacing", value: $doc.cableSpacingMm,
                               range: 0...50, step: 0.5, unit: "mm")
                    Text("Text is tiled across the label width (set width in Paper Settings).")
                        .font(.caption).foregroundColor(.secondary)
                }
            }.padding(.vertical, 4)
        }
    }

    private var qrControls: some View {
        GroupBox("QR Code") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Text or URL", text: $doc.qrText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }.padding(.vertical, 4)
        }
    }

    private func stepperRow(_ label: String, value: Binding<Double>,
                            range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f %@", value.wrappedValue, unit))
                .foregroundColor(.secondary).monospacedDigit()
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
    }

    // MARK: Print

    private var printSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Copies")
                Spacer()
                Text("\(doc.copies)").monospacedDigit().foregroundColor(.secondary)
                Stepper("", value: $doc.copies, in: 1...100).labelsHidden()
            }
            Button(action: printLabel) {
                HStack {
                    if isPrinting { ProgressView().tint(.white) }
                    Text(isPrinting ? "Printing…" : "Print!")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPrinting)
        }
    }

    private var connectionButton: some View {
        Button { showPrinterSheet = true } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(printer.connectionState == .connected ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(printer.connectedName ?? "Connect")
                    .lineLimit(1)
            }
        }
    }

    private func printLabel() {
        guard printer.connectionState == .connected else {
            showPrinterSheet = true
            return
        }
        isPrinting = true
        Task {
            do {
                let bitmap = LabelRasterizer.rasterize(doc)
                try await printer.printLabel(bitmap, segmentedPaper: doc.segmentedPaper, copies: doc.copies)
                alertMessage = "Sent \(doc.copies) label(s) to the printer."
            } catch {
                alertMessage = error.localizedDescription
            }
            isPrinting = false
        }
    }
}
