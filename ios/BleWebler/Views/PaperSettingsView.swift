import SwiftUI

struct PaperSettingsView: View {
    @EnvironmentObject var doc: LabelDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Paper") {
                    Toggle("Continuous roll (infinite)", isOn: $doc.infinitePaper)
                    HStack {
                        Text("Label width")
                        Spacer()
                        Text(String(format: "%.0f mm", doc.paperWidthMm))
                            .foregroundColor(.secondary).monospacedDigit()
                        Stepper("", value: $doc.paperWidthMm, in: 5...300, step: 1).labelsHidden()
                    }
                    Toggle("Die-cut / gapped labels", isOn: $doc.segmentedPaper)
                    Text(doc.segmentedPaper
                         ? "Use for pre-cut labels with gaps between them."
                         : "Use for continuous paper; the printer feeds and cuts between copies.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Printer head") {
                    HStack {
                        Text("Head height")
                        Spacer()
                        Text("\(doc.headHeightPx) px (\(String(format: "%.0f", Double(doc.headHeightPx) / Double(doc.dotsPerMm))) mm)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Resolution")
                        Spacer()
                        Text("\(doc.dotsPerMm * 25) dpi").foregroundColor(.secondary)
                    }
                    Text("Set automatically when a printer connects.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Paper Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
