//
//  NavigatorTreeView.swift
//  Docsy
//
//  Created by Noah Kamara on 21.11.24.
//

import SwiftUI
import SwiftDocC

extension NavigatorTree.Node: @retroactive Identifiable {
    var nonEmptyChildren: [NavigatorTree.Node]? {
        children.isEmpty ? nil : children
    }
}
                           
struct NavigatorIndexView: View {
    let index: NavigatorIndex
    let topLevelId: UInt32
    
    @State
    var selectedLanguage: InterfaceLanguage? = .swift
    
    var body: some View {
        if let languageNode = index.navigatorTree.root.children
            .first(where: { $0.item.languageID == selectedLanguage?.mask }) {
            OutlineGroup(
                languageNode.children,
                children: \NavigatorTree.Node.nonEmptyChildren
            ) { node in
                if let nodeId = node.id {
                    Text(node.item.title)
                        .tag(Navigator.NavigatorID(topLevelId: topLevelId, nodeId: nodeId))
                } else {
                    Text(node.item.title)
                }
            }
        }
    }
}

extension NavigatorTree.Node {
    var topLevelId: UInt32? {
        get { attributes["top-level-id"] as? UInt32 }
        set { attributes["top-level-id"] = newValue }
    }
}

#Preview(traits: .modifier(PreviewWorkspace())) {
    @Previewable @Environment(\.workspace) var workspace
    List {
        ForEach(Array(workspace.navigator.indices.keys), id:\.self) { key in
            NavigatorIndexView(
                index: workspace.navigator.indices[key]!,
                topLevelId: key
            )
        }
    }
}
