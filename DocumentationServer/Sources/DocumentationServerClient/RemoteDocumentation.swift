//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 07.12.24.
//

import Foundation
import AsyncHTTPClient
import DocumentationKit
import NIOHTTP1
import OSLog





public struct HTTPDocumentationRepository {
    let client: any HTTPClientProtocol
    
    public init(client: any HTTPClientProtocol) {
        self.client = client
    }
    
    public init(baseURI: URL) {
        self.init(client: HTTPClient(baseURI: baseURI))
    }
}

extension HTTPDocumentationRepository: DocumentationRepository {
    public func addBundle(
        displayName: String,
        identifier: String
    ) async throws -> BundleDetail {
        try await client.request(
            method: .POST,
            path: "/api/repository",
            body: [
                "displayName": displayName,
                "bundleIdentifier": identifier
            ],
            as: BundleDetail.self
        )
    }

    public func bundle(_ bundleId: BundleDetail.ID) async throws -> BundleDetail? {
        do {
            return try await client.request(
                method: .GET,
                path: "/api/repository/\(bundleId.uuidString)",
                as: BundleDetail.self
            )
        } catch let errorResponse as ErrorResponse {
            if errorResponse.status == 404 {
                return nil
            } else {
                throw errorResponse
            }
        }
    }

    public func search(query: BundleQuery) async throws -> [BundleDetail] {
        try await client.request(
            method: .GET,
            path: "/api/repository",
            as: [BundleDetail].self
        )
    }

    public func searchCompletions(for prefix: String, limit: Int) async throws -> [String] {
        throw AnyError("Not Implemented")
    }

    public func removeBundle(_ bundleId: UUID) async throws {
        try await client.request(method: .DELETE, path: "/api/repository/\(bundleId.uuidString)")
    }

    public func addRevision(
        _ tag: String,
        source: URL,
        toBundle bundleId: UUID
    ) async throws -> BundleRevision {
        try await client.request(
            method: .POST,
            path: "/api/repository/\(bundleId.uuidString)",
            body: [
                "tag": tag,
                "source": source.absoluteString
            ]
        )
    }

    public func revision(_ tag: String, forBundle bundleId: BundleDetail.ID) async throws -> BundleRevision? {
        do {
            return try await client.request(
                method: .GET,
                path: "/api/repository/\(bundleId.uuidString)/\(tag)"
            )
        } catch let error as ErrorResponse {
            guard error.status != 404 else {
                return nil
            }
            
            throw error
        }
    }

    public func removeRevision(_ tag: BundleRevision.Tag, forBundle bundleId: BundleDetail.ID) async throws {
        try await client.request(
            method: .DELETE,
            path: "/api/repository/\(bundleId.uuidString)/\(tag)"
        )
    }
}



struct AnyError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}


