import AppKit
import SafariServices
import SwiftUI

struct ContentView: View {
    private let extensionId = "ca.agare.highlighter.extension"
    @State private var enabled = false
    @State private var note: String?

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

            if enabled {
                Text("Agare is on in Safari. You can close this window.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Turn Agare on in Safari")
                        .font(.headline)
                    Text("1. Open Safari, then Settings (⌘,).")
                    Text("2. Advanced — tick “Show features for web developers”.")
                    Text("3. Developer — tick “Allow unsigned extensions”. Enter your password if asked.")
                    Text("4. Extensions — turn on Agare.")
                        .font(.body)
                    Text("Safari forgets step 3 when it quits. If Agare is missing from the list, quit Safari fully and open Agare again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
            }

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
        .frame(minWidth: 440, minHeight: 320)
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
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
                    note = "Safari doesn’t see Agare yet. Do steps 2–3 first, then quit Safari (Safari menu → Quit Safari) and click this button again."
                    openSafari()
                }
                refresh()
            }
        }
    }

    private func refresh() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionId) { state, _ in
            DispatchQueue.main.async { enabled = state?.isEnabled ?? false }
        }
    }
}
