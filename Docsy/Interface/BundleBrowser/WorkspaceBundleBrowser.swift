//
//  WorkspaceBundleBrowser.swift
//  DocSee
//
//  Created by Noah Kamara on 26.12.24.
//

import Foundation
import SwiftUI


/// An instance of BundleBrowser that allows adding revisions of bundles to a workspace
struct WorkspaceBundleBrowser: View {
    let workspace: Workspace
    let repositories: DocumentationRepositories
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        DocumentationBrowserView(browser: .init(repositories: repositories)) { item in
            if let firstRevision = item.revisions.first {
                Menu {
                    ForEach(item.revisions) { revision in
                        AsyncButton("Add '\(revision.tag)'") {
                            let provider = HTTPBundleRepositoryProvider(
                                rootURL: revision.source
                            )
                            let bundle = try await provider.bundle()
                            try await workspace.addBundle(bundle, with: provider)
                            dismiss()
                        }
                    }
                } label: {
                    AsyncButton("Add '\(firstRevision.tag)' to Workspace") {
                        print("SOURCE", firstRevision.source)
                        let provider = HTTPBundleRepositoryProvider(rootURL: firstRevision.source)
                        let bundle = try await provider.bundle()
                        try await workspace.addBundle(bundle, with: provider)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WorkspaceBundleBrowser(
        workspace: try! .init(config: .init(inMemory: true)),
        repositories: .preview()
    )
}
