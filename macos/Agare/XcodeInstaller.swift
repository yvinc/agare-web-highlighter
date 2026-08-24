import AppKit

enum XcodeInstaller {
    static func run() {
        let alert = NSAlert()
        alert.messageText = "Set up with Xcode?"
        alert.informativeText = """
        This copies the Agare Xcode project onto this Mac and opens it.

        Sign in with a free Apple ID (Xcode → Settings → Accounts). Select the Agare target, choose your Team, press Run. You do not need the paid Developer Program.

        A HowToSign note opens with the same steps.
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
        go.informativeText = "macOS will ask you to run a script. Signing and the Safari registration happen there; Xcode is used to build."
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
