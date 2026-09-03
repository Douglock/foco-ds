import Foundation
import AppKit

enum SuperProductivityLauncher {
    static func activateSuperProductivity() {
        // Find running Super Productivity process
        let runningApps = NSWorkspace.shared.runningApplications
        if let spApp = runningApps.first(where: { app in
            if let bundleId = app.bundleIdentifier, bundleId.localizedCaseInsensitiveContains("super-productivity") {
                return true
            }
            if let name = app.localizedName, name.localizedCaseInsensitiveContains("Super Productivity") {
                return true
            }
            return false
        }) {
            // Unhide if hidden and bring to foreground
            spApp.unhide()
            spApp.activate(options: [.activateIgnoringOtherApps])
            return
        }

        // If not already running, try opening the application
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.super-productivity.app") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config, completionHandler: nil)
            return
        }

        // Direct path fallback
        let defaultAppUrl = URL(fileURLWithPath: "/Applications/Super Productivity.app")
        if FileManager.default.fileExists(atPath: defaultAppUrl.path) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: defaultAppUrl, configuration: config, completionHandler: nil)
        }
    }
}
