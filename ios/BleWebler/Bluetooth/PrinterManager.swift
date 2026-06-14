import Foundation
import CoreBluetooth

enum PrinterError: LocalizedError {
    case notConnected
    case bluetoothUnavailable
    case characteristicMissing
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "No printer connected."
        case .bluetoothUnavailable: return "Bluetooth is not available or not authorised."
        case .characteristicMissing: return "Printer is missing the expected print characteristic."
        case .connectionFailed(let m): return "Connection failed: \(m)"
        }
    }
}

/// A printer found during scanning.
struct DiscoveredPrinter: Identifiable {
    var id: UUID { peripheral.identifier }
    let peripheral: CBPeripheral
    let name: String
    let model: SupportedPrinter?
    let rssi: Int
}

enum PrinterConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

/// Drives the BLE connection and printing. Mirrors the web app's
/// `PrinterBase` / `connectPrinter` flow using CoreBluetooth.
@MainActor
final class PrinterManager: NSObject, ObservableObject {

    @Published var bluetoothReady = false
    @Published var isScanning = false
    @Published var discovered: [DiscoveredPrinter] = []
    @Published private(set) var connectionState: PrinterConnectionState = .disconnected
    @Published private(set) var connectedName: String?
    @Published private(set) var connectedModel: SupportedPrinter?
    @Published private(set) var log: [String] = []

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?

    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Scanning

    func startScan() {
        guard bluetoothReady else { return }
        discovered.removeAll()
        isScanning = true
        // Scan everything and filter by name prefix; advertised services are
        // unreliable on these printers.
        central.scanForPeripherals(withServices: nil, options: nil)
        addLog("Scanning for printers…")
    }

    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
    }

    // MARK: - Connection

    func connect(_ device: DiscoveredPrinter) async throws {
        stopScan()
        if let existing = peripheral, existing.identifier == device.peripheral.identifier,
           connectionState == .connected {
            return
        }
        connectionState = .connecting
        connectedName = device.name
        connectedModel = device.model
        peripheral = device.peripheral
        device.peripheral.delegate = self

        addLog("Connecting to \(device.name)…")
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                connectContinuation = cont
                central.connect(device.peripheral, options: nil)
            }
            connectionState = .connected
            addLog("Connected.")
        } catch {
            connectionState = .disconnected
            addLog("Connect error: \(error.localizedDescription)")
            throw error
        }
    }

    func disconnect() {
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        writeChar = nil
        connectionState = .disconnected
        connectedName = nil
        connectedModel = nil
        addLog("Disconnected.")
    }

    // MARK: - Printing

    func printLabel(_ bitmap: LabelBitmap, segmentedPaper: Bool, copies: Int = 1) async throws {
        guard let peripheral, let writeChar else { throw PrinterError.notConnected }
        let writeType: CBCharacteristicWriteType =
            writeChar.properties.contains(.write) ? .withResponse : .withoutResponse

        for copy in 0..<max(1, copies) {
            addLog("Printing copy \(copy + 1) of \(copies)…")
            let packets = MarklifeProtocol.printPackets(for: bitmap, segmentedPaper: segmentedPaper)
            for packet in packets {
                for chunk in MarklifeProtocol.chunked(packet) {
                    try await write(chunk, to: writeChar, on: peripheral, type: writeType)
                    try await Task.sleep(nanoseconds: 30_000_000) // 30 ms pacing
                }
            }
            if copy < copies - 1 {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        addLog("Print complete.")
    }

    private func write(_ data: Data, to char: CBCharacteristic,
                       on peripheral: CBPeripheral, type: CBCharacteristicWriteType) async throws {
        if type == .withoutResponse {
            peripheral.writeValue(data, for: char, type: .withoutResponse)
            return
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writeContinuation = cont
            peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }

    // MARK: - Logging

    func addLog(_ message: String) {
        let stamp = Self.timeFormatter.string(from: Date())
        log.append("[\(stamp)] \(message)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - CBCentralManagerDelegate

extension PrinterManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                bluetoothReady = true
                addLog("Bluetooth ready.")
            case .poweredOff:
                bluetoothReady = false
                addLog("Bluetooth is powered off.")
            case .unauthorized:
                bluetoothReady = false
                addLog("Bluetooth permission denied. Enable it in Settings.")
            case .unsupported:
                bluetoothReady = false
                addLog("Bluetooth LE is not supported on this device.")
            default:
                bluetoothReady = false
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        guard let name = advName, let model = SupportedPrinter.match(name: name) else { return }
        Task { @MainActor in
            if !discovered.contains(where: { $0.id == peripheral.identifier }) {
                discovered.append(DiscoveredPrinter(peripheral: peripheral, name: name,
                                                    model: model, rssi: RSSI.intValue))
                addLog("Found \(name) (\(model.name))")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            peripheral.discoverServices([PrinterGATT.printService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            finishConnect(throwing: PrinterError.connectionFailed(error?.localizedDescription ?? "unknown"))
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if connectContinuation != nil {
                finishConnect(throwing: PrinterError.connectionFailed(error?.localizedDescription ?? "disconnected"))
            }
            writeContinuation?.resume(throwing: PrinterError.notConnected)
            writeContinuation = nil
            connectionState = .disconnected
            writeChar = nil
        }
    }

    private func finishConnect(throwing error: Error?) {
        guard let cont = connectContinuation else { return }
        connectContinuation = nil
        if let error { cont.resume(throwing: error) } else { cont.resume() }
    }
}

// MARK: - CBPeripheralDelegate

extension PrinterManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                finishConnect(throwing: PrinterError.connectionFailed(error.localizedDescription)); return
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == PrinterGATT.printService }) else {
                finishConnect(throwing: PrinterError.characteristicMissing); return
            }
            peripheral.discoverCharacteristics([PrinterGATT.printCharacteristic], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error {
                finishConnect(throwing: PrinterError.connectionFailed(error.localizedDescription)); return
            }
            guard let char = service.characteristics?.first(where: { $0.uuid == PrinterGATT.printCharacteristic }) else {
                finishConnect(throwing: PrinterError.characteristicMissing); return
            }
            writeChar = char
            finishConnect(throwing: nil)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard let cont = writeContinuation else { return }
            writeContinuation = nil
            if let error { cont.resume(throwing: error) } else { cont.resume() }
        }
    }
}
