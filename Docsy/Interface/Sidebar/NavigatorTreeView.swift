//
//  NavigatorTreeView.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import SwiftDocC
import SwiftUI

extension NavigatorTree.Node: @retroactive Identifiable {
    var nonEmptyChildren: [NavigatorTree.Node]? {
        children.isEmpty ? nil : children
    }
}

struct NavigatorTreeView: View {
    let root: NavigatorTree.Node
    let topLevelId: UInt32
    @Binding
    var selection: Navigator.NavigatorID?

    var body: some View {
        OutlineGroup(root, children: \NavigatorTree.Node.nonEmptyChildren) { node in
            if let nodeId = node.id, node.item.pageType != PageType.groupMarker.rawValue {
                LeafView(item: node.item)
                    .tag(
                        Navigator.NavigatorID(
                            topLevelId: topLevelId,
                            nodeId: nodeId
                        )
                    )
#if os(iOS)
                    .bold(selection?.topLevelId == topLevelId && selection?.nodeId == nodeId)
                    .onTapGesture {
                        selection = .init(topLevelId: topLevelId, nodeId: nodeId)
                    }
                    .tag(
                        Navigator.NavigatorID(
                            topLevelId: topLevelId,
                            nodeId: nodeId
                        )
                    )
#endif

            } else {
                Text(node.item.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .headerProminence(.increased)
                    .environment(\.defaultMinListRowHeight, 0)
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
        @Bindable var navigator = workspace.navigator

        ForEach(Array(workspace.navigator.indices.keys), id: \.self) { key in
            NavigatorTreeView(
                root: workspace.navigator.indices[key]!.navigatorTree.root,
                topLevelId: key,
                selection: $navigator.selection
            )
        }
    }
}

// MARK: Leaf

struct LeafView: View {
    var item: NavigatorItem

    @Environment(\.supportsMultipleWindows)
    private var supportsMultipleWindows

    var body: some View {
        Group {
            if let pageType = PageType(rawValue: item.pageType) {
                if case .groupMarker = pageType {
                    Text(item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                } else {
                    Label {
                        Text(item.title)
                    } icon: {
                        PageTypeIcon(pageType)
                    }
                }
            } else {
                Text("Inalid Page Type: \(item.pageType)")
            }
        }
        .lineLimit(1, reservesSpace: true)
    }
}

typealias PageType = NavigatorIndex.PageType

struct PageTypeIcon: View {
    enum Icon {
        case abbr(String, Color)
        case symbol(String)
        case unknown(PageType)
    }

    let icon: Icon

    init(_ type: NavigatorIndex.PageType) {
        self.init(type.icon)
    }

    init(_ icon: Icon) {
        self.icon = icon
    }

    @Environment(\.isFocused)
    var isFocused

    var body: some View {
        Group {
            switch icon {
            case .abbr(let abbreviation, let color):
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .aspectRatio(1, contentMode: .fit)
                        .foregroundStyle(color.secondary)

                    Text(abbreviation)
                        .foregroundStyle(isFocused ? color : .white)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(2)

            case .symbol(let systemImage):
                Image(systemName: systemImage)
                    .padding(2)

            case .unknown(let type):
                Text("UNKNOWN \(type.rawValue)")
                    .foregroundStyle(.red)
                    .onAppear {
                        print("unknown", type.rawValue)
                    }
            }
        }
    }
}

#Preview {
    PageTypeIcon(.article)
}

private extension PageType {
    var icon: PageTypeIcon.Icon {
        switch self {
        case .root: .symbol("square.grid.2x2")
        case .article: .symbol("text.document")
        case .overview: .symbol("app.connected.to.app.below.fill")
        case .tutorial: .symbol("square.fill.text.grid.1x2")
        //        case .section:
        //        case .learn:
        //        case .overview: .abbr("OV", .red)
        //        case .resources:
        case .symbol: .symbol("list.bullet")
        case .framework: .symbol("square.stack.3d.up.fill")
        case .class: .abbr("C", .purple)
        case .structure: .abbr("S", .purple)
        case .protocol: .abbr("Pr", .purple)
        case .enumeration, .enumerationCase: .abbr("E", .purple)
        case .function, .instanceMethod, .initializer: .abbr("M", .purple)
        case .extension: .abbr("Ex", .orange)
        case .typeAlias: .abbr("T", .yellow)
        //        case .associatedType:
        case .operator: .abbr("Op", .green)
        //        case .macro:
        //        case .union:
        case .instanceProperty: .abbr("P", .purple)
//            case .subscript:
        //        case .typeMethod:
        //        case .typeProperty:
        //        case .buildSetting:
        //        case .propertyListKey:
        case .sampleCode: .symbol("curlybraces")
        //        case .httpRequest:
        //        case .dictionarySymbol:
        //        case .namespace:
        //        case .propertyListKeyReference:
        //        case .languageGroup:
        //        case .container:
        //        case .groupMarker:
        default: .unknown(self)
        }
    }
}
