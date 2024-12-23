//
//  BundleBrowserWindow.swift
//  DocSee
//
//  Created by Noah Kamara on 20.12.24.
//

import SwiftUI
import DocumentationKit

extension BundleDetail.Revision {
    func provider() {
        HTTPBundleRepositoryProvider(rootURL: source)
    }
}

struct HTTPBundleRepositoryProvider: BundleRepositoryProvider {
    public let identifier: String = UUID().uuidString

    let rootURL: URL

    /// Creates a new provider that provides a documentation bundle at the baseuri
    /// - Parameter rootURL: The location that this provider searches for documentation bundles in.
    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    /// - Parameter path: the path to the content
    /// - Returns: The contents of the file at path
    public func data(for path: String) async throws -> Data {
        let url = rootURL.appending(path: path)
        return try Data(contentsOf: url)
    }

    public func contentsOfURL(_ url: consuming URL) throws -> Data {
        precondition(url.isFileURL, "Unexpected non-file url '\(url)'.")
        return try Data(contentsOf: url)
    }

    public func bundle() async throws -> DocumentationBundle {
        try createBundle(at: rootURL)
    }

    func createBundle(at url: URL) throws -> DocumentationBundle {
        let metadataData = try Data(contentsOf: url.appending(components: "metadata.json"))

        let decoder = JSONDecoder()

        let metadata = try decoder.decode(DocumentationBundle.Metadata.self, from: metadataData)

        return DocumentationBundle(
            info: metadata,
            baseURL: URL(filePath: "/"),
            indexPath: "/index"
        )
    }
}


struct BundleBrowserWindow: Scene {
    let workspace: Workspace
    let repositories: DocumentationRepositories
    
    var body: some Scene {
        Window("Bundle Browser", id: WindowID.bundleBrowser.identifier) {
            DocumentationBrowserView(repositories) { item in
                ItemDetailView(bundle: item)
                    .toolbar {
                        if let firstRevision = item.revisions.first {
                            Menu {
                                ForEach(item.revisions) { revision in
                                    AsyncButton("Add '\(revision.tag)'") {
                                        let provider = HTTPBundleRepositoryProvider(
                                            rootURL: revision.source
                                        )
                                        let bundle = try await provider.bundle()
                                        try await workspace.addBundle(bundle, with: provider)
                                    }
                                }
                            } label: {
                                AsyncButton("Add '\(firstRevision.tag)' to Workspace") {
                                    print("SOURCE", firstRevision.source)
                                    let provider = HTTPBundleRepositoryProvider(rootURL: firstRevision.source)
                                    let bundle = try await provider.bundle()
                                    try await workspace.addBundle(bundle, with: provider)
                                }
                            }
                        }
                    }
            }
        }
        .defaultSize(width: 300, height: 300)
        .windowIdealPlacement({ content, context in
            let minSize = content.sizeThatFits(.zero)
            print(minSize)
            
            return .init(.zero, size: minSize)
        })
        .windowResizability(.contentMinSize)
        .windowManagerRole(.associated)
        .windowToolbarStyle(.unifiedCompact)
        .defaultLaunchBehavior(.suppressed)
    }
}
