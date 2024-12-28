//
//  DocumentationBrowserView.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import SwiftUI
import DocumentationKit
import DocumentationServerClient
import SplitView


struct DocumentationBrowserView<Actions: View>: View {
    @State
    private var selection: BundleDetail? = nil
    @Bindable
    private var browser: DocumentationBrowser
    private let bundleActions: (BundleDetail) -> Actions
    
    init(
        browser: DocumentationBrowser,
        @ViewBuilder bundleActions: @escaping (BundleDetail) -> Actions
    ) {
        self.browser = browser
        self.bundleActions = bundleActions
    }
    
    init(
        browser: DocumentationBrowser
    ) where Actions == EmptyView {
        self.init(browser: browser, bundleActions: { _ in EmptyView() })
    }
    
    @State
    var isShowingSearch: Bool = true
    
    @State
    var isShowingImporter: Bool = false
        
    var body: some View {
        content
            .sheet(isPresented: $isShowingImporter) {
                NavigationStack {
                    if let localRepo = browser.repositories[.local] {
                        BundleImportView(
                            importer: .init(repository: localRepo)
                        )
                    } else {
                        ContentUnavailableView("Local Repository is unavailable.", systemImage: "exclamationmark.octagon")
                    }
                }
                .padding()
            }
            .searchable(
                text: $browser.searchTerm,
                isPresented: $isShowingSearch
            )
            .searchScopes($browser.scopes, activation: .onSearchPresentation, {
                Text("All").tag(Set(browser.repositories.scopes))
                
                ForEach(browser.repositories.scopes.sorted(), id:\.self) { scope in
                    Text(scope.displayName).tag(Set([scope]))
                }
            })
            .task(id: browser.id) {
                do {
                    try await browser.bootstrap()
                } catch {
                    print("failed to bootstrap source browser: \(error)")
                }
            }
    }
    
    var bottomBar: some View {
        HStack {
            Button("Add Custom", action: {
                self.isShowingImporter = true
            })
            .frame(maxWidth: .infinity, alignment: .leading)
            
            
            if let selection {
                bundleActions(selection)
            }
        }
        .padding(12)
        .background(.background)
    }
    
    var detail: some View {
        Group {
            if let selection {
                BundleBrowserDetailView(bundle: selection)
                //                .toolbar {
                //                    ToolbarItem(placement: .bottomBar) {
                //                        bundleActions(selection)
                //                    }
                //                }
            } else {
                Text("Select a bundle")
            }
        }
    }
    
    var content: some View {
        VStack(spacing: 0) {
            HSplit {
                BundleBrowserResultsList(browser.items, selection: $selection)
                    .toolbar(removing: .sidebarToggle)
                    .frame(minWidth: 160, idealWidth: 240)
            } right: {
                detail
                    .frame(
                        minWidth: 200,
                        idealWidth: 350,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
            .fraction(0.4)
            .styling(
                color: .secondary.opacity(0.3),
                inset: 0,
                visibleThickness: 1,
                hideSplitter: true
            )
            
            Divider()
            
            bottomBar
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
    
    let browser = DocumentationBrowser(repositories: .init(repos: [
        .local: repository,
        .cloud: HTTPDocumentationRepository(baseURI: URL(string: "http://localhost:1234")!)
    ]))
    
    DocumentationBrowserView(browser: browser)
        .frame(width: 600, height: 300)
}


extension BundleDetail: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(metadata.id)
        hasher.combine(metadata.bundleIdentifier)
    }
}


// MARK: Detail
struct BundleBrowserDetailView: View {
    let bundle: BundleDetail
    
    @State
    var showPrereleases = false

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
        Table(filteredVersions(term: versionTerm)) {
            TableColumn("Tag", value: \.tag)
                .width(min: 10)
            TableColumn("Source") { rev in
                if rev.source.isFileURL {
                    Text(rev.source.path())
                } else {
                    Text(rev.source.formatted(.url.scheme(.omitIfHTTPFamily)))
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading) {
                Text(bundle.metadata.displayName)
                    .font(.title2)
                
                TextField("", text: $versionTerm, prompt: Text("Filter Revisions"))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: nil)
            }
            .padding(10)
        }
    }
}

#Preview("BundleBrowser: Detail") {
    BundleBrowserDetailView(bundle: .init(
        metadata: .init(
            id: .init(),
            displayName: "DocumentationKit",
            bundleIdentifier: "com.example.DocumentationKit"
        ),
        revisions: [
            .init(tag: "latest", source: URL(string: "https://example.com/documentationkit/latest")!),
            .init(tag: "1.0.0", source: URL(string: "https://example.com/documentationkit/1.0.0")!),
            .init(tag: "0.1.0", source: URL(string: "https://example.com/documentationkit/0.1.0")!)
        ]
    ))
}



// MARK: ResultsList
fileprivate struct BundleBrowserResultsList: View {
    @Binding
    var selection: BundleDetail?
    var items: [BundleDetail]
    
    init(_ items: [BundleDetail], selection: Binding<BundleDetail?>) {
        self._selection = selection
        self.items = items
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            List(selection: $selection) {
                ForEach(items) { item in
                    DocumentationBrowserItemView(item: item)
                        .tag(item)
                }
                .listRowInsets(.init(top: 5, leading: 0, bottom: 5, trailing: 0))
            }
            .onChange(of: items) { _, items in
                if let first = items.first {
                    scrollProxy.scrollTo(first.id, anchor: .top)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.visible)
    }
}

#Preview("BundleBrowser: ResultsList") {
    @Previewable
    @State
    var selection: BundleDetail? = nil
    
    BundleBrowserResultsList([], selection: $selection)
}

// MARK: ResultsList Item
struct DocumentationBrowserItemView: View {
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

extension DocumentationBrowserItemView {
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
