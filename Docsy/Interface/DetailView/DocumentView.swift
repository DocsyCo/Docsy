//
//  DocumentView.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import BundledDocumentationRenderer
import DocumentationKit
import DocumentationRenderer
import SwiftUI
import WebKit

extension BundleRepository: @retroactive FileServerProvider {
    public func data(for path: String) async throws -> Data {
        print("BUNDLEREPO", path)
        return Data()
    }
}

private let bundleSpecificSubpaths: [String] = [
    "data",
    "downloads",
    "images",
    "videos",
    "index",
]

private let appSourcePaths: [String] = [
    "documentation",
    "tutorials",
    "js",
    "css",
    "img",
    "index.html",
]

class OverridenFileServerProvider: FileServerProvider {
    let bundleRepository: BundleRepository
    let appSource: FileServerProvider
    let theme: ThemeSettings
    
    init(
        repository: BundleRepository,
        appSource: FileServerProvider,
        theme: ThemeSettings = .docsee
    ) {
        self.bundleRepository = repository
        self.appSource = appSource
        self.theme = theme
    }

    func data(for path: String) async throws -> Data {
        var components = path.split(separator: "/")

        guard !components.isEmpty else {
            fatalError("not enough path components: '\(path)'")
        }

        let bundleIdentifier = String(components.removeFirst())
        let restPath = components.joined(separator: "/")
        
        let documentationURI = DocumentationURI(
            bundleIdentifier: bundleIdentifier,
            path: restPath
        )
        
        if restPath == "theme-settings.json" {
            do {
                return try await bundleRepository.contentsOfUrl(documentationURI)
            } catch let originalError {
                do {
                    return try JSONEncoder().encode(theme)
                } catch {
                    throw originalError
                }
            }
        }

        if let bundleSubPath = components.first.map(String.init) {
            if appSourcePaths.contains(bundleSubPath) {
                return try await appSource.data(for: restPath)
            } else if bundleSubPath.contains(bundleSubPath) {
                return try await bundleRepository.contentsOfUrl(documentationURI)
            }
        }

        if appSourcePaths.contains(bundleIdentifier) {
            return try await appSource.data(for: path)
        }

        throw ProviderError.notFound
    }
}

struct DocumentView: View {
    let navigator: Navigator
    let renderer: DocumentationRenderer

    init(workspace: Workspace) {
        let provider = OverridenFileServerProvider(
            repository: workspace.bundleRepository,
            appSource: BundledAppSourceProvider()
        )

        self.renderer = DocumentationRenderer(provider: provider)
        self.navigator = workspace.navigator
    }

    @Environment(\.supportsMultipleWindows)
    private var supportsMultipleWindows

    @Environment(\.openURL)
    private var openURL

    func navigatorDidChangeSelection(_ selection: Navigator.NavigatorID) {
        guard let topicURL = navigator.topicUrl(for: selection) else {
            return
        }

        renderer.navigate(to: .init(bundleIdentifier: topicURL.bundleIdentifier, path: topicURL.path))
    }

    @MainActor
    func viewerUrlDidChange(_ url: DocumentationURI) {
        let url = DocumentationURI(bundleIdentifier: url.bundleIdentifier, path: url.path)
        navigator.navigate(to: url)
    }

    var body: some View {
        DocumentationView(renderer)
            .ignoresSafeArea(.container, edges: .all)
            // Open foreign urls
            .onAppear(perform: {
                renderer.openUrlAction = { url in
                    openURL(url, completion: {
                        if !$0 {
                            print("failed to open url\(url)")
                        }
                    })
                }
            })
            .toolbar {
                ToolbarItem(id: "navigation", placement: .navigation) {
                    NavigationButtons(renderer: renderer)
                }
            }
            // watch Sidebar changes
            .onChange(of: navigator.selection, initial: true) { oldValue, newValue in
                guard let newValue, newValue != oldValue else { return }
                navigatorDidChangeSelection(newValue)
            }
            // Watch Viewer Changes
            .onChange(of: renderer.url) { oldValue, newValue in
                guard let newValue, newValue != oldValue else { return }
                viewerUrlDidChange(newValue)
            }
    }
}

// #Preview {
//    DocumentView()
// }

// MARK: Navigation Buttons

private struct NavigationButtons: View {
    let renderer: DocumentationRenderer

    var body: some View {
        ControlGroup {
            Button(action: { renderer.goBack() }) {
                Image(systemName: "chevron.backward")
            }
            .disabled(!renderer.canGoBack)

            Button(action: { renderer.goForward() }) {
                Image(systemName: "chevron.forward")
            }
            .disabled(!renderer.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}
