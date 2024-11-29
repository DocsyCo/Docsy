//
//  DocumentationView.swift
//  DocCViewer
//
//  Copyright © 2024 Noah Kamara.
//

import OSLog
import SwiftUI
import WebKit
import Observation
import DocumentationKit


@Observable
public final class DocumentationRenderer {
    @MainActor
    public var url: DocumentationURI? = nil
    
    @MainActor
    public var openUrlAction: @MainActor (URL) -> Void = { print("opened url without handler: \($0)") }

    let provider: FileServerProvider
    
    var context: DocumentationViewContext?
    public internal(set) var canGoBack: Bool = false
    public internal(set) var canGoForward: Bool = false
    

    
    public init(provider: FileServerProvider) {
        self.provider = provider
    }
    
    @MainActor
    public func navigate(to url: DocumentationURI) {
        guard let context else {
            return
        }
        context.navigate(to: url)
    }
}

extension DocumentationRenderer {
    @MainActor public func goBack() {
        self.context?.goBack()
    }
    
    @MainActor public func goForward() {
        self.context?.goForward()
    }
}


public extension URL {
    static let doc = URL(string: "doc://")!
}

struct PreviewProvider: FileServerProvider {
    let baseURI: URL

    init(baseURI: URL = URL(string: "https://developer.apple.com/")!) {
        self.baseURI = baseURI
    }

    func data(for path: String) async throws -> Data {
        let url = baseURI.appending(path: path)
        return try await URLSession.shared.data(from: url).0
    }
}


