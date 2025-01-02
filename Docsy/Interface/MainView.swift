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

    @State
    private var columnVisibility: NavigationSplitViewVisibility = .all
    
    
    #if os(iOS)
    @Environment(DocumentationRepositories.self)
    private var repositories
    #endif
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(navigator: workspace.navigator)
                .navigationSplitViewColumnWidth(min: 180, ideal: 260)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        OpenBundleBrowserButton()
                    }
                }
        } detail: {
            DocumentView(workspace: workspace)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            do {
                let provider = PreviewDataProvider.bundle
                let bundles = try provider.findBundles(limit: 5, where: { _ in true })

                try await withThrowingTaskGroup(of: Void.self) { tasks in
                    for bundle in bundles {
                        tasks.addTask {
                            try await workspace.addBundle(bundle, with: provider)
                        }
                        try await tasks.waitForAll()
                    }
                }
            } catch {
                print("failed to add preview bundles with error: \(error)")
            }
        }
    }
}

#Preview {
    MainView(workspace: try! Workspace(config: .init(inMemory: true)))
}
