//
//  DocumentationBrowserView.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import Combine
import DocumentationKit
import SwiftUI

struct DocumentationBrowserView: View {
    @Bindable
    var browser: DocumentationBrowser

    init(repository: DocumentationRepository) {
        self.browser = DocumentationBrowser(repository: repository)
    }

    @State
    var selection: BundleDetail.ID? = nil

    var body: some View {
        NavigationSplitView {
            ScrollViewReader { scrollProxy in
                List(selection: $selection) {
                    ForEach(browser.items) { item in
                        ItemView(item: item)
                            .tag(item.id)
                    }
                    .listRowInsets(.init(top: 5, leading: 0, bottom: 5, trailing: 0))
                }
                .onChange(of: browser.items) { _, items in
                    guard let first = items.first else { return }
                    scrollProxy.scrollTo(first.id, anchor: .top)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.visible)
            .navigationSplitViewColumnWidth(min: 150, ideal: 250)
            .navigationTitle("Documentation")
            .searchable(text: $browser.searchTerm)
        } detail: {
            if let id = selection, let bundle = browser.items.first(where: { $0.id == id }) {
                ItemDetailView(bundle: bundle)
            } else {
                Text("Select a bundle")
            }
        }

        .task(id: browser.id) {
            do {
                try await browser.bootstrap()
            } catch {
                print("failed to bootstrap source browser: \(error)")
            }
        }
    }
}

#Preview {
    @Previewable let repository: any DocumentationRepository = {
        let documentationKit = BundleMetadata(
            id: UUID(),
            displayName: "DocumentationKit",
            bundleIdentifier: "app.getdocsy.documentationkit"
        )

        let documentationServer = BundleMetadata(
            id: UUID(),
            displayName: "DocumentationServer",
            bundleIdentifier: "app.getdocsy.documentationServer"
        )

        return InMemoryDocumentationRepository(
            bundles: [documentationKit, documentationServer],
            revisions: [
                documentationKit.id: [
                    "0.1.0": URL(filePath: "/" + UUID().uuidString),
                    "0.1.1": URL(filePath: "/" + UUID().uuidString),
                ],
                documentationServer.id: [
                    "0.1.0": URL(filePath: "/" + UUID().uuidString),
                    "0.1.1": URL(filePath: "/" + UUID().uuidString),
                    "0.1.2": URL(filePath: "/" + UUID().uuidString),
                ],
            ]
        )
    }()

    DocumentationBrowserView(repository: repository)
        .frame(width: 500, height: 300)
}

// MARK: Item View

private extension DocumentationBrowserView {
    struct ItemView: View {
        let item: DocumentationBrowser.Item

        var body: some View {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text(item.metadata.displayName)
                            .fontWeight(.medium)

                        Text(item.metadata.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.8)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                RevisionsScrollView(revisions: item.revisions)
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(.container, edges: .horizontal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct RevisionsScrollView: View {
        let revisions: [BundleDetail.Revision]

        var body: some View {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(revisions, id: \.tag) { revision in
                        Text(revision.tag)
                    }
                    .font(.caption)
                    .padding(3)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                    .background(Color.teal.quaternary, in: .rect(cornerRadius: 5))
                }
                .lineLimit(1)
            }
            .contentMargins(.horizontal, 5, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

public enum BundleRevisionKind: CaseIterable {
    case release
    case preRelease
}

extension Set<BundleRevisionKind> {
    static let all: Set<BundleRevisionKind> = [.release, .preRelease]
}

private extension DocumentationBrowserView {
    struct ItemDetailView: View {
        let bundle: BundleDetail

        @State
        var showPrereleases = false

        @State
        var sortOrder = [
            SortDescriptor(\BundleDetail.Revision.tag, order: .reverse),
        ]

        @State
        var versionTerm: String = ""

        func filteredVersions(term: String) -> [BundleDetail.Revision] {
            if term.isEmpty {
                bundle.revisions
            } else {
                bundle.revisions.filter { $0.tag.contains(versionTerm) }
            }
        }

        var body: some View {
            Table(filteredVersions(term: versionTerm), sortOrder: $sortOrder) {
                TableColumn("Tag", value: \.tag)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading) {
                    Text(bundle.metadata.displayName)
                        .font(.title)

                    TextField("", text: $versionTerm, prompt: Text("Search versions"))
                        .textFieldStyle(.roundedBorder)
                }
                .padding(10)
            }
        }
    }
}
