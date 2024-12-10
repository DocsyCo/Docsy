//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 08.12.24.
//

import Foundation
import DocumentationKit
import Hummingbird

// MARK: RevisionController
struct RevisionController<Repository: DocumentationRepository> {
    let repository: Repository
    
    init(repository: Repository) {
        self.repository = repository
    }
    
    var endpoints: RouteCollection<BasicRequestContext> {
        RouteCollection<BasicRequestContext>()
            .post("/", use: create)
            .get("/:tag", use: detail)
//            .put("/:tag", use: update)
            .delete("/:tag", use: delete)
    }
    
    struct CreateRequest: Decodable {
        let tag: String
        let source: URL
    }
    
    @Sendable
    func create(_ request: Request, context: BasicRequestContext) async throws -> BundleRevision {

        let bundleId = try context.parameters.require("bundleId", as: UUID.self)
        
        let request = try await request.decode(as: CreateRequest.self, context: context)
        
        return try await repository.addRevision(
            request.tag,
            source: request.source,
            toBundle: bundleId
        )
    }
    
    @Sendable
    func detail(_ request: Request, context: BasicRequestContext) async throws -> BundleRevision {
        let bundleId = try context.parameters.require("bundleId", as: UUID.self)
        let tag = try context.parameters.require("tag")
        
        guard let revision = try await repository.revision(tag, forBundle: bundleId) else {
            throw ErrorResponse(
                status: .notFound,
                detail: "no revision with bundleId='\(bundleId)' tag='\(tag)'"
            )
        }
        
        return revision
    }
    
    @Sendable
    func update(_ request: Request, context: BasicRequestContext) async throws -> BundleRevision {
        throw ErrorResponse(status: .notFound, detail: nil)
    }
    
    @Sendable
    func delete(_ request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {
        let bundleId = try context.parameters.require("bundleId", as: UUID.self)
        let tag = try context.parameters.require("tag")
        try await repository.removeRevision(tag, forBundle: bundleId)
        return Response(status: .accepted)
    }
}
