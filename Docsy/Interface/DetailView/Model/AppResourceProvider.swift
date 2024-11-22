//
//  AppResourceProvider.swift
//  Docsy
//
//  Created by Noah Kamara on 21.11.24.
//

import DocCViewer
import Foundation
import DocumentationKit

enum DocsyResourceProviderError: Error {
    case invalidURL(String)
    case loadingFailed(any Error)
}


class DocsyResourceProvider: BundleResourceProvider, AsyncFileServerProvider {
    func data(for path: String) async throws -> Data  {
        var components = path
            .trimmingCharacters(in: .init(charactersIn: "/"))
            .split(separator: "/")
        
        guard !components.isEmpty else {
            print("empty path")
            throw FileServerProviderError.notFound
        }
        
        let bundleIdentifier = components.removeFirst()
        let topicUrl = TopicURL(
            bundleIdentifier: String(bundleIdentifier),
            path: components.joined(separator: "/")
        )

        return try await context.contentsOfUrl(topicUrl.url)
    }

    let context: DocumentationContext

    init(context: DocumentationContext) {
        self.context = context
    }

    func provideAsset(_ kind: BundleAssetKind, forBundle identifier: String, at path: String) async throws(DocsyResourceProviderError) -> Data {
        let urlString = "doc://\(identifier)\(path)"

        guard let url = URL(string: urlString) else {
            throw .invalidURL(urlString)
        }

        do {
            let data = try await context.contentsOfUrl(url)
            return data
        } catch {
            throw .loadingFailed(error)
        }
    }
}

public enum ContextError: Error {
    case unknownBundle(BundleIdentifier)
}
