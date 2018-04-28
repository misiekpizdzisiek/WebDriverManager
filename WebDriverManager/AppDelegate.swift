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

#if DEBUG
let debug = true
#else
let debug = false
#endif

import Cocoa
import os.log

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
        
        @IBOutlet weak var statusMenu: NSMenu!
        
        func applicationDidFinishLaunching(_ aNotification: Notification) {
                NSUserNotificationCenter.default.delegate = WebDriverNotifications.shared
                WebDriverNotifications.shared.beginUpdateCheck()
        }
        
        func keyEquivalent(with event: NSEvent) {
                DispatchQueue.main.async {
                        if event.type == NSEvent.EventType.keyDown {
                                let modifierFlags: UInt = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
                                if modifierFlags == NSEvent.ModifierFlags.command.rawValue {
                                        if let menuDelegate = self.statusMenu.delegate as? StatusMenuController {
                                                switch event.keyCode {
                                                case 18:
                                                        menuDelegate.showPackageInstallerMenuItemClicked(_: self)
                                                case 19:
                                                        menuDelegate.openInBrowserMenuItemClicked(_: self)
                                                case 43:
                                                        menuDelegate.preferencesMenuItemClicked(_: self)
                                                default:
                                                        break
                                                }
                                        }
                                }
                        }
                }
        }
}
