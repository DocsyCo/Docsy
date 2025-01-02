//
//  OpenBundleBrowserButton.swift
//  Docsy
//
//  Created by Noah Kamara on 28.12.24.
//

import SwiftUI

struct OpenBundleBrowserButton: View {
    @Environment(AppModel.self)
    var appModel
    
    @Environment(\.openWindow)
    var openWindow
    
    @Environment(\.supportsMultipleWindows)
    private var supportsMultipleWindows
    
    var body: some View {
        Button(action: {
            if supportsMultipleWindows {
                openWindow(WindowID.bundleBrowser)
            } else {
                appModel.showsBundleBrowser = true
            }
        }) {
            Label("Bundle Browser", systemImage: "doc.text.magnifyingglass")
        }
        .keyboardShortcut("b", modifiers: .command)
    }
}

#Preview {
    OpenBundleBrowserButton()
}


@Observable
class AppModel {
    var showsBundleBrowser: Bool = false
}
