import SwiftUI

struct PrinterView: View {
    @EnvironmentObject var printer: PrinterManager
    @EnvironmentObject var doc: LabelDocument
    @Environment(\.dismiss) private var dismiss
    @State private var connectingID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                statusSection
                if printer.connectionState != .connected {
                    devicesSection
                }
                logSection
            }
            .navigationTitle("Printer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if printer.isScanning {
                        Button("Stop") { printer.stopScan() }
                    } else {
                        Button("Scan") { printer.startScan() }
                            .disabled(!printer.bluetoothReady)
                    }
                }
            }
            .onAppear {
                if printer.bluetoothReady && printer.connectionState == .disconnected {
                    printer.startScan()
                }
            }
            .onDisappear { printer.stopScan() }
            .alert("Bluetooth", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            if !printer.bluetoothReady {
                Label("Bluetooth not ready — enable it in Settings.", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            }
            if printer.connectionState == .connected {
                HStack {
                    Label(printer.connectedName ?? "Connected", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Button("Disconnect", role: .destructive) { printer.disconnect() }
                }
                if let info = printer.connectedModel?.info {
                    Text(info).font(.caption).foregroundColor(.secondary)
                }
            } else if printer.connectionState == .connecting {
                HStack { ProgressView(); Text("Connecting…") }
            } else {
                Text(printer.isScanning ? "Scanning…" : "Not connected")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var devicesSection: some View {
        Section("Discovered printers") {
            if printer.discovered.isEmpty {
                Text(printer.isScanning ? "Searching…" : "No printers found yet.")
                    .foregroundColor(.secondary)
            }
            ForEach(printer.discovered) { device in
                Button { connect(device) } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                            if let model = device.model {
                                Text(model.name).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if connectingID == device.id {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(connectingID != nil)
            }
        }
    }

    private var logSection: some View {
        Section("Log") {
            ForEach(Array(printer.log.suffix(12).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption.monospaced()).foregroundColor(.secondary)
            }
        }
    }

    private func connect(_ device: DiscoveredPrinter) {
        connectingID = device.id
        Task {
            do {
                try await printer.connect(device)
                doc.applyModel(printer.connectedModel)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            connectingID = nil
        }
    }
}
