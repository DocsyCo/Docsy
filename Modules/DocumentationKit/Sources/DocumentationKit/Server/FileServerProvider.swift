//
//  File.swift
//  DocumentationKit
//
//  Created by Noah Kamara on 22.11.24.
//

import Foundation

public enum FileserverProviderError: Error {
    case notFound
}

/// A protocol used for serving content to a `FileServer`.
/// > This abstraction lets a `FileServer` provide content from multiple types of sources at the same time.
public protocol FileServerProvider {
    typealias ProviderError = FileserverProviderError
    
    /// Retrieve the data linked to a given path based on the `baseURL`.
    ///
    /// - parameter path: The path.
    /// - returns: The data matching the url, if possible.
    func data(for path: String) async throws -> Data
}
