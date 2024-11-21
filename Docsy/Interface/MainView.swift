//
//  ContentView.swift
//  Docsy
//
//  Created by Noah Kamara on 19.11.24.
//

import SwiftUI

struct MainView: View {
    @Namespace
    var namespace
    
    var workspace = try! Workspace(config: .init(inMemory: true))
    
    var body: some View {
        NavigationSplitView {
            SidebarView(navigator: workspace.navigator)
        } detail: {
//            DetailView()
            Text("HELLO WORLDaaaaaaaaa")
                .navigationDestination(for: Int.self) {
                    Text("Hi \($0)")
                }
        }
        .task {
            try? await Task.sleep(for: .seconds(1))
            do {
                let provider = PreviewDataProvider.bundle
                let bundles = try provider.findBundles(where: { _ in true })
                
                for bundle in bundles {
                    print(bundle.baseURL)
                    print("REGISTERING")
                    try await workspace.addBundle(bundle, with: provider)
                }
            } catch {
              print("failed to add preview bundles with error: \(error)")
            }
        }
    }
}

#Preview {
    MainView()
}
