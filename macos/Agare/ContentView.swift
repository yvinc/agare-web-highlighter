import AppKit
import SafariServices
import SwiftUI

struct ContentView: View {
    private let extensionId = "ca.agare.highlighter.extension"
    @State private var enabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agare")
                        .font(.title.weight(.medium))
                    Text("召し上がれ")
                        .font(.title3.italic())
                        .foregroundStyle(.secondary)
                }
            }

            if enabled {
                Text("Agare is on. You can quit this window and highlight in Safari.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("One more step — turn Agare on in Safari.")
                        .font(.callout)
                    Text("If the list is empty, open Safari → Settings → Developer and tick “Allow unsigned extensions”, then come back here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(enabled ? "Safari Extensions…" : "Turn on in Safari…") {
                SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionId) { _ in
                    refresh()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(minWidth: 420, minHeight: 260)
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
    }

    private func refresh() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionId) { state, _ in
            DispatchQueue.main.async { enabled = state?.isEnabled ?? false }
        }
    }
}
