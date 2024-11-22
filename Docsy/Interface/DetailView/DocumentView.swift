//
//  DocumentView.swift
//  Docsy
//
//  Created by Noah Kamara on 21.11.24.
//

import SwiftUI
import DocCViewer
import BundleAppSourceProvider
import DocumentationKit
import WebKit


extension BundleAppSourceProvider: @retroactive AsyncFileServerProvider {}

public class AppResourceOverrideRouter: FileServerRouter {
    private static let allowedBundlePathPrefixes: [String.SubSequence?] = [
        "downloads",
        "images",
        "videos",
        "index",
        "data",
        "theme-settings.json",
        nil
    ]
    
    private static let allowedAppSourcePathPrefixes: [String.SubSequence?] = [
        nil,
        "js",
        "css",
        "img",
        "index.html"
    ]
    
    let app: AsyncFileServerProvider
    let bundle: AsyncFileServerProvider

    public init(app: AsyncFileServerProvider, bundle: AsyncFileServerProvider) {
        self.app = app
        self.bundle = bundle
    }

    
    public override func data(for path: String) async throws -> Data {
        var components = path
            .trimmingCharacters(in: .init(charactersIn: "/"))
            .split(separator: "/")
        
        guard let firstComponent = components.first else {
            return try await app.data(for: "index.html")
        }
        
        let fromSecondPath = components.dropFirst()
        let secondComponent = fromSecondPath.first
        
        print(firstComponent, secondComponent)
        if Self.allowedAppSourcePathPrefixes.contains(firstComponent) {
            return try await app.data(for: path)
        } else if let secondComponent {
            if Self.allowedBundlePathPrefixes.contains(secondComponent) {
                return try await bundle.data(for: path)
            } else if Self.allowedAppSourcePathPrefixes.contains(secondComponent) {
                return try await app.data(for: fromSecondPath.joined(separator: "/"))
            } else {
                fatalError("Unknwon")
            }
        } else {
            fatalError("OH NO \(path)")
        }
    }
}


struct DocumentView: View {
    let navigator: Navigator

    @State
    var viewer: DocumentationViewer

    init(workspace: Workspace) {
        let bundleProvider = DocsyResourceProvider(context: workspace)
        let appSourceProvider = BundleAppSourceProvider(bundleProvider: bundleProvider)
        
        let router = AppResourceOverrideRouter(
            app: appSourceProvider,
            bundle: bundleProvider
        )
        
        self.viewer = DocumentationViewer(
            provider: router,
            globalThemeSettings: .docsee
        )
        self.navigator = workspace.navigator
    }

    @Environment(\.supportsMultipleWindows)
    private var supportsMultipleWindows

    @Environment(\.openURL)
    private var openURL

    
    func navigatorDidChangeSelection(_ selection: Navigator.NavigatorID) {
        print("Navigator did change selection: \(selection)")
        
        guard let topicURL = navigator.topicUrl(for: selection) else {
            return
        }
        
        viewer.navigate(to: .init(bundleIdentifier: topicURL.bundleIdentifier, path: topicURL.path))
    }
    
    @MainActor
    func viewerUrlDidChange(_ url: URL) {
        guard let url = DocumentationURI(url: url) else {
            print("INVALID")
            return
        }
        navigator.navigate(to: url)
    }
    
    var body: some View {
        DocumentationView(viewer: viewer)
            .toolbar {
                ToolbarItem(id: "navigation", placement: .navigation) {
                    NavigationButtons(viewer: viewer)
                }
            }
            .onChange(of: navigator.selection, initial: true) { (oldValue, newValue) in
                guard let newValue, newValue != oldValue else { return }
                navigatorDidChangeSelection(newValue)
            }
            .task(id: "url-did-change") {
                do {
                    let urlDidChangePublisher = viewer.bridge.channel(for: .didNavigate)

                    let urlDidChangeNotifications = await urlDidChangePublisher.values(as: URL.self)

                    for try await url in urlDidChangeNotifications {
                        viewerUrlDidChange(url)
                    }
                } catch {
                    print("failed to receive url changes: \(error)")
                }
            }
            .task(id: "open-url") {
                do {
                    let events = await viewer.bridge.channel(for: .openURL).values(as: URL.self)

                    for try await url in events {
                        openURL(url, completion: {
                            if !$0 {
                                print("failed to open url\(url)")
                            }
                        })
                    }
                } catch {
                    print("failed to receive openUrl", error)
                }
            }
    }
}

//#Preview {
//    DocumentView()
//}


// MARK: Navigation Buttons
fileprivate struct NavigationButtons: View {
    let viewer: DocumentationViewer

    var body: some View {
        ControlGroup {
            Button(action: { viewer.goBack() }) {
                Image(systemName: "chevron.backward")
            }
            .disabled(!viewer.canGoBack)

            Button(action: { viewer.goForward() }) {
                Image(systemName: "chevron.forward")
            }
            .disabled(!viewer.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

