//
//  MainView.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import SwiftUI

struct MainView: View {
    @Namespace
    var namespace

    let workspace: Workspace

    var body: some View {
        NavigationSplitView {
            SidebarView(navigator: workspace.navigator)
        } detail: {
            DocumentView(workspace: workspace)
        }
//        .task {
//            do {
//                let provider = PreviewDataProvider.bundle
//                let bundles = try provider.findBundles(limit: 5, where: { _ in true })
//
//                try await withThrowingTaskGroup(of: Void.self) { tasks in
//                    for bundle in bundles {
//                        tasks.addTask {
//                            try await workspace.addBundle(bundle, with: provider)
//                        }
//                        try await tasks.waitForAll()
//                    }
//                }
//            } catch {
//                print("failed to add preview bundles with error: \(error)")
//            }
//        }
    }
}

#Preview {
    MainView(workspace: try! Workspace(config: .init(inMemory: true)))
}
