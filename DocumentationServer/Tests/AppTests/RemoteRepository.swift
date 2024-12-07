//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 07.12.24.
//

import Foundation
import HummingbirdTesting
import DocumentationKit


struct TestRepository {
    let client: any TestClientProtocol
    
    init(client: TestClientProtocol) {
        self.client = client
    }
}

extension TestRepository: DocumentationRepository {
    func addBundle(
        displayName: String,
        identifier: String
    ) async throws -> BundleDetail {
        let response = try await client.executeRequest(
            uri: "/api/bundles",
            method: .post,
            headers: .init(),
            body: try
                .encoding([
                    "displayName": displayName,
                    "bundleIdentifier": identifier
                ])
        )
        
        return try response.json()
    }

    func bundle(_ bundleId: BundleDetail.ID) async throws -> BundleDetail? {
        let response = try await client.executeRequest(
            uri: "/api/bundles/\(bundleId.uuidString)",
            method: .get,
            headers: .init(),
            body: nil
        )
        
        return try response.json()
    }

    func search(query: BundleQuery) async throws -> [BundleDetail] {
        let response = try await client.executeRequest(
            uri: "/api/bundles",
            method: .get,
            headers: .init(),
            body: nil
        )
        
        return try response.json()
    }

    func searchCompletions(for prefix: String, limit: Int) async throws -> [String] {
        throw AnyError("Not Implemented")
    }

    func removeBundle(_ bundleId: UUID) async throws {
        let response = try await client.executeRequest(
            uri: "/api/bundles/\(bundleId.uuidString)",
            method: .delete,
            headers: .init(),
            body: nil
        )
        
        try response.raiseStatus()
    }

    func addRevision(
        _ tag: String,
        source: URL,
        toBundle bundleId: UUID
    ) async throws -> BundleRevision {
        let response = try await client.executeRequest(
            uri: "/api/bundles/\(bundleId.uuidString)/revisions",
            method: .post,
            headers: .init(),
            body: try .encoding([
                    "tag": tag,
                    "source": source.absoluteString
                ])
        )
        
        
        return try response.json()
    }

    func revision(_ tag: String, forBundle bundleId: BundleDetail.ID) async throws -> BundleRevision? {
        let response = try await client.executeRequest(
            uri: "/api/bundles/\(bundleId.uuidString)/revisions/\(tag)",
            method: .get,
            headers: .init(),
            body: nil
        )
        
        guard response.status != 404 else {
            return nil
        }
        
        return try response.json()
    }

    func removeRevision(_ tag: BundleRevision.Tag, forBundle bundleId: BundleDetail.ID) async throws {
        let response = try await client.executeRequest(
            uri: "/api/bundles/\(bundleId.uuidString)/revisions/\(tag)",
            method: .delete,
            headers: .init(),
            body: nil
        )
        
        try response.raiseStatus()
    }
}
