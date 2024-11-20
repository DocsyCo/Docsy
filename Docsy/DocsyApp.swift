//
//  DocsyApp.swift
//  Docsy
//
//  Created by Noah Kamara on 19.11.24.
//

import SwiftUI

extension Project {
    static func scratchpad() -> Project {
        Project(displayName: "Scratchpad", items: [], references: [:])
    }
}

@main
struct DocsyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
