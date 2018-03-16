/*
 * File: Packager.swift
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

class Packager {

        let fileManager = FileManager()
        let packagerQueue = DispatchQueue(label: "packager", attributes: .concurrent)
        var packagerWorkItem: DispatchWorkItem?
        
        @discardableResult func list(archive: String) -> Int32 {
                let task = Process()
                task.launchPath = "/usr/bin/xar"
                task.arguments = ["-tf", archive]
                task.launch()
                task.waitUntilExit()
                return (task.terminationStatus)
        }
        
        @discardableResult func extract(archive: String, destinationDirectory directory: String) -> Int32 {
                let task = Process()
                task.launchPath = "/usr/bin/xar"
                task.arguments = ["-xf", archive, "-C", directory]
                task.launch()
                task.waitUntilExit()
                return (task.terminationStatus)
        }
        
        @discardableResult func archive(sourceDirectory directory: String, destination: String, files: [String]) -> Int32 {
                let task = Process()
                task.launchPath = "/usr/local/bin/xar-mackyle"
                task.arguments = ["-cf", destination, "-C", "\(directory)"] + files
                task.launch()
                task.waitUntilExit()
                return (task.terminationStatus)
        }
        
        @discardableResult func install(package: String) -> Int32 {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-b", "com.apple.installer", "--args", package]
                task.launch()
                task.waitUntilExit()
                return (task.terminationStatus)
        }
        
        func installPackage(atUrl url: URL) {
                packagerQueue.async {
                        self.installPackageDidFinish(result: self._installPackage(url))
                }
        }
        
        private func installPackageDidFinish(result: Bool) {
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.showPackageDropMenuItem.isEnabled = true
                }
        }
        
        private func _installPackage(_ url: URL) -> Bool {
                let base = NSTemporaryDirectory()
                let uuid = NSUUID().uuidString
                let temp = "\(base)\(uuid)"
                let extracted = "\(temp)/tmp"
                print(extracted)
                if !fileManager.fileExists(atPath: url.path) {
                        os_log("Package or other file type not found")
                        return false
                }
                guard list(archive: url.path) == 0 else {
                        os_log("Not a xar archive")
                        return false
                }
                
                do {
                        try fileManager.removeItem(atPath: temp)
                } catch {
                        os_log("Nothing to remove")
                }
                do {
                        try fileManager.createDirectory(atPath: extracted, withIntermediateDirectories: true, attributes: nil)
                } catch {
                        os_log("Failed to create temporary directory")
                        return false
                }
                os_log("Extracting to %{public}@", extracted)
                if extract(archive: url.path, destinationDirectory: extracted) != 0 {
                        os_log("Failed to extract package")
                        return false
                }
                let distribution = "\(extracted)/Distribution"
                if !fileManager.fileExists(atPath: distribution) {
                        os_log("Distribution not found")
                        return false
                }
                if Liberator(URL.init(fileURLWithPath: distribution)) == nil {
                        os_log("PackagerViewController: Failed to patch Distribution")
                        return false
                }
                let subpaths = fileManager.subpaths(atPath: extracted)
                guard subpaths != nil else {
                        os_log("Failed to get sub paths for archiving")
                        return false
                }
                var files: [String] = []
                var name = "RepackagedWebDrivers.pkg"
                do {
                        let contents: [String] = try fileManager.contentsOfDirectory(atPath: extracted)
                        for item in contents {
                                if item.uppercased().contains("DRIVER") {
                                        name = item
                                }
                                if !item.uppercased().contains("PREFPANE") {
                                        os_log("Adding %{public}@ to file list", item)
                                        files.append(item)
                                }
                        }
                } catch {
                        os_log("Failed to get contents of directory for archiving")
                        return false
                }
                let output = "\(temp)/\(name)"
                if archive(sourceDirectory: "\(extracted)", destination: output, files: files) != 0 {
                        os_log("Failed to archive package")
                        return false
                }
                if let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent(name) {
                        do {
                                try fileManager.copyItem(at: URL.init(fileURLWithPath: output), to: desktop)
                        } catch {
                                os_log("Failed to make a copy of driver package on the desktop")
                        }
                }
                os_log("Will attempt to launch GUI installer for %{public}@", output)
                
                if install(package: output) == 0 {
                        return true
                } else {
                        os_log("Open command returned a non-zero exit status")
                        return false
                }
        }
}