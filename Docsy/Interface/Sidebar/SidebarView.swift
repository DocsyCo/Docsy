//
//  SidebarView.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import SwiftDocC
import SwiftUI

struct SidebarView: View {
    @Bindable
    var navigator: Navigator

    func getNode(for reference: DocumentationURI) -> NavigatorTree.Node? {
        let internalID = navigator.bundleIdToTopLevelId[reference.bundleIdentifier]!
        let index = navigator.indices[internalID]!

        guard let nodeId = index.id(for: reference.path, with: .swift) else {
            return nil
        }

        return index.navigatorTree.numericIdentifierToNode[nodeId]
    }

    var body: some View {
        List(selection: $navigator.selection) {
            if !navigator.nodes.isEmpty {
                ForEach(navigator.nodes, id: \.displayID) { topLevelNode in
                    if let reference = topLevelNode.reference,
                       !topLevelNode.isLoading,
                       let node = getNode(for: reference),
                       !node.children.isEmpty
                    {
                        NavigatorTreeView(
                            root: node,
                            topLevelId: navigator.bundleIdToTopLevelId[reference.bundleIdentifier]!,
                            selection: $navigator.selection
                        )
                    } else {
                        Label {
                            Text(topLevelNode.displayName)
                        } icon: {
                            PageTypeIcon(.root)
                        }
                        .safeAreaInset(edge: .trailing) {
                            if topLevelNode.isLoading {
                                ProgressView()
                                    .controlSize(.mini)
                            } else if let error = topLevelNode.error {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .onAppear {
                                        print(error)
                                    }
                            }
                        }
                    }
                }
                .onMove { indices, newOffset in
                    navigator.move(fromOffsets: indices, toOffset: newOffset)
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
