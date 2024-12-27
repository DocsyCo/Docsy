//
//  BundleBrowserWindow.swift
//  DocSee
//
//  Created by Noah Kamara on 20.12.24.
//

import SwiftUI
import DocumentationKit


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
    
#if os(macOS)
    var body: some Scene {
        Window("Bundle Browser", id: WindowID.bundleBrowser.identifier) {
            WorkspaceBundleBrowser(workspace: workspace, repositories: repositories)
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
#else
    var body: some Scene {
        WindowGroup(id: WindowID.bundleBrowser.identifier) {
            WorkspaceBundleBrowser(workspace: workspace, repositories: repositories)
        }
        .defaultSize(width: 300, height: 300)
        .windowResizability(.contentMinSize)
    }
#endif
}


