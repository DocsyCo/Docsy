//
//  DocsyApp.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
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
            MainView()
        }
    }
}
