//
//  SidebarView.swift
//  Docsy
//
//  Created by Noah Kamara on 21.11.24.
//

import SwiftUI

struct SidebarView: View {
    @Bindable
    var navigator: Navigator
    
    var body: some View {
        List(selection: $navigator.selection) {
            if !navigator.nodes.isEmpty {
                ForEach(navigator.nodes, id:\.displayID) { node in
                    if !node.isLoading, let topLevelId = node.id, let index = navigator.indices[topLevelId] {
                        NavigatorIndexView(
                            index: index,
                            topLevelId: topLevelId,
                            selection: $navigator.selection
                        )
                    } else {
                        Label {
                            Text(node.displayName)
                        } icon: {
                            PageTypeIcon(.root)
                        }
                        .safeAreaInset(edge: .trailing) {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                }
            } else {
                Text("No Nodes yes")
            }
        }
        .listStyle(.sidebar)
    }
}

extension EnvironmentValues {
    @Entry var workspace: Workspace = try! Workspace(config: .init(inMemory: true))
}

struct PreviewWorkspace: PreviewModifier {
    static func makeSharedContext() async throws -> Workspace {
        let workspace = try! Workspace(
            config: .init(inMemory: true),
            fileManager: .default
        )
        
        do {
            let provider = PreviewDataProvider.bundle
            let bundles = try provider.findBundles(where: { _ in true })
            
            for bundle in bundles {
                try await workspace.addBundle(bundle, with: provider)
            }
        } catch {
            print("failed to add preview bundles with error: \(error)")
        }
        
        return workspace
    }
    
    func body(content: Content, context: Workspace) -> some View {
        content
            .environment(\.workspace, context)
    }
}

#Preview(traits: .modifier(PreviewWorkspace())) {
    @Previewable @Environment(\.workspace)
    var workspace
    
    NavigationStack {
        SidebarView(navigator: workspace.navigator)
            .navigationDestination(for: Navigator.NavigatorID.self) { id in
                VStack(alignment: .leading) {
                    Text(" Compound: \(id.rawValue)")
                    Text("Top Level: \(id.topLevelId)")
                    Text("     Node: \(id.nodeId)")
                }
                .monospaced()
            }
    }
}

import DocumentationKit


