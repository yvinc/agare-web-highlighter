import AppKit

enum XcodeInstaller {
    static func run() {
        let alert = NSAlert()
        alert.messageText = "Set up with Xcode?"
        alert.informativeText = """
        First time with Xcode: open Xcode → Settings → Accounts → + → Apple ID and sign in with your free iCloud account. You do not need the paid Developer Program.

        Then this helper stamps that Team on Agare and AgareExtension and builds. Safari will quit once so the extension can appear.
        """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard xcodeInstalled() else {
            let missing = NSAlert()
            missing.messageText = "Xcode isn’t installed"
            missing.informativeText = "Install Xcode from the App Store, open it once, then try this again."
            missing.addButton(withTitle: "Open App Store")
            missing.addButton(withTitle: "OK")
            if missing.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "macappstores://apps.apple.com/app/xcode/id497799835") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        guard let command = Bundle.main.url(forResource: "InstallWithXcode", withExtension: "command") else {
            let fail = NSAlert()
            fail.messageText = "Setup script missing"
            fail.informativeText = "This copy of Agare doesn’t include the Xcode helper. Download Agare.app from GitHub Releases."
            fail.runModal()
            return
        }

        let go = NSAlert()
        go.messageText = "Open Terminal to continue?"
        go.informativeText = "macOS will ask you to run a script. If an Apple ID is already in Xcode Accounts, signing and the build happen there automatically."
        go.addButton(withTitle: "Open helper")
        go.addButton(withTitle: "Cancel")
        guard go.runModal() == .alertFirstButtonReturn else { return }

        NSWorkspace.shared.open(command)
    }

    static func xcodeInstalled() -> Bool {
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") != nil {
            return true
        }
        return FileManager.default.fileExists(atPath: "/Applications/Xcode.app")
    }
}
