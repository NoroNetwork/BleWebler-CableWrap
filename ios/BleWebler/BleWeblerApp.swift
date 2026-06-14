import SwiftUI

@main
struct BleWeblerApp: App {
    @StateObject private var printer = PrinterManager()
    @StateObject private var doc = LabelDocument()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(printer)
                .environmentObject(doc)
        }
    }
}
