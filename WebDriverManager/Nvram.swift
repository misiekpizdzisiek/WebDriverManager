/*
 * File: Nvram.swift
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

import Foundation

class Nvram: RegistryEntry {
        
        static let shared = Nvram()
        
        var useNvidia: Bool {
                get {
                        if let result: Data = getDataValue(forProperty: "nvda_drv") {
                                if result == Data(bytes: [0x31, 0x0]) || result == Data(bytes: [0x31]) {
                                        return true
                                }
                        }
                        return false
                }
        }
        
        init?() {
                super.init(fromPath: "IODeviceTree:/options")
        }

}
