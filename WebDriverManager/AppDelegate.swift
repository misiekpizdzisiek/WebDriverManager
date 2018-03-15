/*
 * File: AppDelegate.swift
 *
 * WebDriverManager © vulgo 2018
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import Cocoa
import os.log

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
        
        static let versionString = "1.4"
        
        let nvdaStartupFind = Data.init(bytes: [0x4e, 0x56, 0x44, 0x41, 0x52, 0x65, 0x71, 0x75, 0x69, 0x72, 0x65, 0x64, 0x4f, 0x53, 0x00])
        let nvdaStartupReplace = Data.init(bytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        var driverStatus: String = NSLocalizedString("Driver status unavailable", comment: "Main menu: Driver status unavailable")
        let driverNotInstalledMenuItemTitle = NSLocalizedString("Web driver not installed", comment: "Main menu: Web driver not installed")
        let driverNotInUseMenuItemTitle = NSLocalizedString("Web driver not in use", comment: "Main menu: Web driver not in use")
        let checkNowMenuItemTitle = NSLocalizedString("Check Now", comment: "Main menu: Check Now")
        let checkInProgressMenuItemTitle = NSLocalizedString("Check in progress...", comment: "Main menu: Check in progress")
        let disableNotificationsMenuItemTitle = NSLocalizedString("Disable Update Notifications", comment: "Main menu: Disable update notifications")
        let enableNotificationsMenuItemTitle = NSLocalizedString("Enable Update Notifications", comment: "Main menu: Enable update notifications")
        let notificationsEnabledMenuItemTitle = NSLocalizedString("Notifications: Enabled", comment: "Main menu: Notifications enabled")
        let notificationsDisabledMenuItemTitle = NSLocalizedString("Notifications: Disabled", comment: "Main menu: Notifications disabled")
        let restartAlertMessage = NSLocalizedString("Settings will be applied after you restart.", comment: "Restart alert: message")
        let restartAlertInformativeText = NSLocalizedString("Your bootloader may override the choice you make here.", comment: "Restart alert: informative text")
        let restartAlertButtonTitle = NSLocalizedString("Close", comment: "Restart alert: button title")
        
        var storyboard: NSStoryboard?
        var aboutWindowController: NSWindowController?
        
        @IBOutlet weak var statusMenu: NSMenu!
        @IBOutlet weak var driverStatusMenuItem: NSMenuItem!
        @IBOutlet weak var useNvidiaDriverMenuItem: NSMenuItem!
        @IBOutlet weak var useDefaultDriverMenuItem: NSMenuItem!
        @IBOutlet weak var checkNowMenuItem: NSMenuItem!
        @IBOutlet weak var notificationsStatusMenuItem: NSMenuItem!
        @IBOutlet weak var toggleNotificationsMenuItem: NSMenuItem!
        @IBOutlet weak var aboutMenuItem: NSMenuItem!
        @IBOutlet weak var quitMenuItem: NSMenuItem!
        @IBOutlet weak var cloverSeparatorMenuItem: NSMenuItem!
        @IBOutlet weak var cloverSubMenuItem: NSMenuItem!
        @IBOutlet weak var nvdaStartupMenuItem: NSMenuItem!
        @IBOutlet weak var nvidiaWebMenuItem: NSMenuItem!
        
        var userWantsAlerts: Bool {
                get {
                        return !Defaults.shared.disableUpdateAlerts
                }
        }
        let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        let nvAccelerator = RegistryEntry.init(fromMatchingDictionary: IOServiceMatching("nvAccelerator"))
        let nvram = Nvram()
        var nvramScriptError: NSDictionary?
        var nvramScript: NSAppleScript?
        let fileManager = FileManager()
        let cloverSettings = CloverSettings()
        let webDriverNotifications = WebDriverNotifications()
        let updateCheckQueue = DispatchQueue(label: "updateCheck", attributes: .concurrent)
        var updateCheckWorkItem: DispatchWorkItem?
        var updateCheckInterval: Double = 21600

        override init() {
                super.init()
                if let nvramScriptUrl = Bundle.main.url(forResource: "nvram", withExtension: "applescript") {
                        nvramScript = NSAppleScript(contentsOf: nvramScriptUrl, error: &nvramScriptError)
                } else {
                        os_log("Failed to get resource url for nvram script")
                }
        }

        func applicationDidFinishLaunching(_ aNotification: Notification) {
                if let button = statusItem.button {
                        button.image = NSImage(named:NSImage.Name("NVMenuIcon"))
                }
                statusItem.isVisible = true
                statusItem.behavior = NSStatusItem.Behavior.terminationOnRemoval
                statusItem.menu = statusMenu
                statusMenu.delegate = self
                NSUserNotificationCenter.default.delegate = webDriverNotifications
                os_log("Started")
                updateCheckQueue.async {
                        self.updateCheckDidFinish(result: self.beginUpdateCheck())
                }
                storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
                aboutWindowController = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "aboutWindowController")) as? NSWindowController
        }
        
        func menuWillOpen(_ menu: NSMenu) {
                if fileManager.fileExists(atPath: "/Library/Extensions/NVDAStartupWeb.kext") {
                        if let bundleId: String = nvAccelerator.getStringValue(forProperty: "CFBundleIdentifier"), bundleId.uppercased().contains("WEB") {
                                driverStatus = "\(bundleId)"
                        } else {
                                driverStatus = driverNotInUseMenuItemTitle
                        }
                        useNvidiaDriverMenuItem.isEnabled = true
                        useDefaultDriverMenuItem.isEnabled = true
                        driverStatusMenuItem.title = driverStatus
                } else {
                        useNvidiaDriverMenuItem.isEnabled = false
                        useDefaultDriverMenuItem.isEnabled = false
                        driverStatusMenuItem.title = driverNotInstalledMenuItemTitle
                }
                if nvram.useNvidia {
                        useNvidiaDriverMenuItem.state = .on
                        useDefaultDriverMenuItem.state = .off
                } else {
                        useNvidiaDriverMenuItem.state = .off
                        useDefaultDriverMenuItem.state = .on
                }
                if Defaults.shared.disableUpdateAlerts {
                        notificationsStatusMenuItem.title = notificationsDisabledMenuItemTitle
                        toggleNotificationsMenuItem?.title = enableNotificationsMenuItemTitle
                } else {
                        notificationsStatusMenuItem.title = notificationsEnabledMenuItemTitle
                        toggleNotificationsMenuItem?.title = disableNotificationsMenuItemTitle
                }
                if cloverSettings != nil {
                        cloverSeparatorMenuItem.isHidden = false
                        cloverSubMenuItem.isHidden = false
                        if let runtimeVariables = cloverSettings?.dictionary?["RtVariables"] as? NSDictionary {
                                let nvidiaWeb: Bool? = runtimeVariables["NvidiaWeb"] as? Bool
                                if nvidiaWeb != nil, nvidiaWeb! == true {
                                        nvidiaWebMenuItem.state = .on
                                } else {
                                        nvidiaWebMenuItem.state = .off
                                }
                        }
                        var enabledPatchesIndicies = IndexSet()
                        if let kernelAndKextPatches = cloverSettings?.dictionary?["KernelAndKextPatches"] as? NSDictionary {
                                if let kextsToPatch = kernelAndKextPatches["KextsToPatch"] as? NSArray {
                                        enabledPatchesIndicies = kextsToPatch.indexesOfObjects(options: [], passingTest: { (constraint, idx, stop) in
                                                if let dict = constraint as? NSDictionary {
                                                        if (dict["Find"] as? Data == nvdaStartupFind && dict["Name"] as? String == "NVDAStartupWeb" && dict["Disabled"] as? Bool != Optional(Bool(true))) {
                                                                return true
                                                        }
                                                }
                                                return false
                                        })
                                }
                        }
                        if enabledPatchesIndicies.count > 0 {
                                nvdaStartupMenuItem.state = .on
                        } else {
                                nvdaStartupMenuItem.state = .off
                        }
                } else {
                        cloverSeparatorMenuItem.isHidden = true
                        cloverSubMenuItem.isHidden = true
                }
        }
        
        @IBAction func changeDriverMenuItemClicked(_ sender: NSMenuItem) {
                if sender.state == .on {
                        return
                }
                os_log("Setting nvda_drv nvram variable")
                let result: NSAppleEventDescriptor? = nvramScript?.executeAndReturnError(&nvramScriptError)
                if (result?.booleanValue)! {
                        if Defaults.shared.showRestartAlert {
                                makeAndShowRestartAlert()
                        }
                        return
                }
                NSSound.beep()
                os_log("Failed to set nvda_drv NVRAM variable")
        }
        
        func cancelSuppressedVersion() {
                if Defaults.shared.suppressUpdateAlerts != "" {
                        Defaults.shared.suppressUpdateAlerts = ""
                        os_log("Cancelling suppressUpdateAlerts")
                }
        }
        
        @IBAction func checkNowMenuItemClicked(_ sender: NSMenuItem) {
                cancelSuppressedVersion()
                updateCheckQueue.async {
                        self.updateCheckDidFinish(result: self.beginUpdateCheck(overrideDefaults: true))
                }
        }
        
        @IBAction func toggleNotificationsMenuItemClicked(_ sender: NSMenuItem) {
                if Defaults.shared.disableUpdateAlerts {
                        cancelSuppressedVersion()
                        Defaults.shared.disableUpdateAlerts = false
                        os_log("Automatic update notifications enabled")
                        updateCheckQueue.async {
                                self.updateCheckDidFinish(result: self.beginUpdateCheck(overrideDefaults: true))
                        }
                } else {
                        Defaults.shared.disableUpdateAlerts = true
                        os_log("Automatic update notifications disabled")
                }
        }
        
        func beginUpdateCheck(overrideDefaults: Bool = false) -> Bool {
                updateCheckWorkItem?.cancel()
                checkNowMenuItem.isEnabled = false
                toggleNotificationsMenuItem.isEnabled = false
                checkNowMenuItem.title = checkInProgressMenuItemTitle
                if userWantsAlerts || overrideDefaults {
                        if !userWantsAlerts && overrideDefaults {
                                os_log("Overriding notifications disabled user default")
                        }
                        return webDriverNotifications.checkForUpdates()
                } else {
                        os_log("Update notifications are disabled in user defaults")
                        return false
                }
        }
        
        func updateCheckDidFinish(result: Bool) {
                os_log("updateCheck returned %{public}@", result.description)
                checkNowMenuItem.isEnabled = true
                toggleNotificationsMenuItem.isEnabled = true
                checkNowMenuItem.title = checkNowMenuItemTitle
                if userWantsAlerts {
                        updateCheckWorkItem = DispatchWorkItem {
                                self.updateCheckDidFinish(result: self.beginUpdateCheck())
                        }
                        updateCheckQueue.asyncAfter(deadline: DispatchTime.now() + updateCheckInterval, execute: updateCheckWorkItem!)
                }
        }
        
        func makeAndShowRestartAlert() {
                let alert = NSAlert()
                alert.messageText = restartAlertMessage
                alert.informativeText = restartAlertInformativeText
                alert.alertStyle = .informational
                alert.addButton(withTitle: restartAlertButtonTitle)
                alert.showsSuppressionButton = true
                alert.runModal()
                if (alert.suppressionButton?.state == .on) {
                        Defaults.shared.showRestartAlert = false
                }
        }
        
        func showWindowInFront(_ window: NSWindow) {
                window.level = .floating
                window.makeKeyAndOrderFront(self)
                window.level = .normal
        }
        
        @IBAction func aboutMenuItemClicked(_ sender: NSMenuItem) {
                if let window = aboutWindowController?.window {
                        if !window.isVisible {
                                window.center()
                        }
                        showWindowInFront(window)
                }
        }
        
        @IBAction func quitMenuItemClicked(_ sender: NSMenuItem) {
                os_log("Quit menu item clicked, exiting")
                exit(0)
        }
        
}
