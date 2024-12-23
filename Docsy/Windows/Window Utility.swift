//
//  Windows.swift
//  DocSee
//
//  Created by Noah Kamara on 20.12.24.
//

import SwiftUI

extension OpenWindowAction {
    func callAsFunction<T: Codable & Hashable>(_ windowID: WindowID<T>, value: T) {
        callAsFunction(id: windowID.identifier, value: value)
    }
    func callAsFunction(_ windowID: WindowID<Void>) {
        callAsFunction(id: windowID.identifier)
    }

}

struct WindowID<T> {
    let identifier: String
    
    init(_ identifier: String) {
        self.identifier = identifier
    }
}

extension WindowID where T == Void {
    static let main = WindowID("main")
    static let bundleBrowser = WindowID("bundleBrowser")
}
