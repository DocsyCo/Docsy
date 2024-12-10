//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 07.12.24.
//

import Foundation
import Hummingbird
import DocumentationKit


// MARK: BundleController
struct BundleController<Repository: DocumentationRepository> {
    private let repository: Repository
    fileprivate let revisionController: RevisionController<Repository>
    
    init(repository: Repository) {
        self.repository = repository
        self.revisionController = RevisionController(repository: repository)
    }
    
    var endpoints: RouteCollection<BasicRequestContext> {
        RouteCollection<BasicRequestContext>()
            .get("/", use: index)
            .post("/", use: create)
            .get("/:id", use: detail)
            .patch("/:id", use: update)
            .delete("/:id", use: delete)
            .addRoutes(revisionController.endpoints, atPath: "/:bundleId/revisions")
    }
    
    func index(_ request: Request, context: BasicRequestContext) async throws -> [BundleDetail] {
        return try await repository.bundles()
    }
    
    struct CreateRequest: Decodable {
        let displayName: String
        let bundleIdentifier: String
    }
    
    @Sendable
    func create(_ request: Request, context: BasicRequestContext) async throws -> BundleDetail {
        let request = try await request.decode(as: CreateRequest.self, context: context)
        return try await repository.addBundle(
            displayName: request.displayName,
            identifier: request.bundleIdentifier
        )
    }
    
    @Sendable
    func detail(_ request: Request, context: BasicRequestContext) async throws -> BundleDetail {
        let id = try context.parameters.require("id", as: UUID.self)
        
        guard let bundle = try await repository.bundle(id) else {
            throw ErrorResponse(status: .notFound, detail: "no bunle with id='\(id)'")
        }
        
        return bundle
    }
    
    @Sendable
    func update(_ request: Request, context: BasicRequestContext) async throws -> BundleDetail {
        throw ErrorResponse(status: .notFound, detail: nil)
    }
    
    @Sendable
    func delete(_ request: Request, context: BasicRequestContext) async throws -> some ResponseGenerator {
        let id = try context.parameters.require("id", as: UUID.self)
        
        try await repository.removeBundle(id)
        
        return Response(status: .accepted)
    }
}

// MARK: Models
extension BundleDetail: @retroactive ResponseEncodable {}
extension BundleRevision: @retroactive ResponseEncodable {}

