import AppKit
import SafariServices
import SwiftUI

struct ContentView: View {
    private let extensionId = "ca.agare.highlighter.extension"
    @State private var enabled = false
    @State private var note: String?
    @State private var stamp = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agare")
                        .font(.title.weight(.medium))
                    Text("Safari highlighter – 召し上がれ")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text(enabled ? "On in Safari" : "Not enabled in Safari yet")
                .font(.caption.weight(.medium))
                .foregroundStyle(enabled ? Color.secondary : Color.orange)

            VStack(alignment: .leading, spacing: 8) {
                Text("Turn Agare on in Safari")
                    .font(.headline)
                Text("First time: Xcode → Settings → Accounts → add your free Apple ID, then Set up with Xcode. The helper signs both Agare targets and builds. No paid Developer Program.")
                Text("Then Safari → Settings → Extensions → turn on Agare.")
                Text("If Agare is missing, run Set up with Xcode again and wait until Safari reopens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Button("Set up with Xcode…") { XcodeInstaller.run() }
                    .keyboardShortcut(.defaultAction)
                Text("Run this the first time you use Agare on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Open Safari") { openSafari() }
                Button("Show Extensions list") { showExtensions() }
            }
        }
        .padding(28)
        .frame(minWidth: 440, minHeight: 340)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func openSafari() {
        let safari = URL(fileURLWithPath: "/Applications/Safari.app")
        NSWorkspace.shared.openApplication(at: safari, configuration: NSWorkspace.OpenConfiguration())
    }

    private func showExtensions() {
        note = nil
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionId) { error in
            DispatchQueue.main.async {
                if error != nil {
                    note = "Safari still doesn’t see Agare. Run Set up with Xcode again so it can sign and register the extension."
                    openSafari()
                }
                refresh()
            }
        }
    }

    private func refresh() {
        stamp += 1
        let n = stamp
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionId) { state, _ in
            DispatchQueue.main.async {
                guard n == stamp else { return }
                enabled = state?.isEnabled == true
            }
        }
    }
}
