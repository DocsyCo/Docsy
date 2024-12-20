//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import HummingbirdTesting
import Testing
import Foundation
import DocumentationKit
@testable import DocumentationServer
@testable import DocumentationServerClient


@Suite
struct RepositoryAPITests {
    let repo: InMemoryDocumentationRepository
    let server: DocumentationServer
    
    init() async {
        self.repo = InMemoryDocumentationRepository()
        self.server = DocumentationServer(configuration: .test)
        
        await self.server.registerService(RepositoryService(repository: repo))
    }
    
    @Test
    func createBundle() async throws {
        let app = try await server.application()
        
        let displayName = "DocumentationKit"
        let bundleIdentifier = "com.example.DocumentationKit"

        let returnedBundle = try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            
            return try await repository.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            )
        }
        
        #expect(returnedBundle.revisions == [])
        #expect(returnedBundle.metadata.displayName == displayName)
        #expect(returnedBundle.metadata.bundleIdentifier == bundleIdentifier)

        let createdBundle = try await #require(repo.bundleMap[returnedBundle.id])
        #expect(returnedBundle.id == createdBundle.id)
    }
    
    @Test
    func getBundle() async throws {
        let app = try await server.application()
        
        let bundle = await repo.addBundle(
            displayName: "DocumentationKit",
            identifier: "com.example.DocumentationKit"
        )
        
        let returnedBundleOpts = try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            return try await repository.bundle(bundle.id)
        }
        
        let returnedBundle = try #require(returnedBundleOpts)
        #expect(returnedBundle.revisions == [])
        #expect(returnedBundle.metadata.displayName == bundle.metadata.displayName)
        #expect(returnedBundle.metadata.bundleIdentifier == bundle.metadata.bundleIdentifier)

        let createdBundle = try await #require(repo.bundleMap[returnedBundle.id])
        #expect(returnedBundle.id == createdBundle.id)
    }
    
    @Test
    func listBundles() async throws {
        let app = try await server.application()
        
        // must be sorted alphabetically
        let bundleInfo = [
            ("DocumentationKit", "com.example.DocumentationKit"),
            ("OtherKit", "com.example.OtherKit")
        ]
        
        for (displayName, bundleIdentifier) in bundleInfo {
            _ = await repo.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            )
        }
        
        let bundleList = try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            
            return try await repository
                .bundles()
                .sorted(by: { $0.metadata.displayName < $1.metadata.displayName })
        }
        
        try #require(bundleList.count == bundleInfo.count)
        #expect(bundleList[0].metadata.displayName == bundleInfo[0].0)
        #expect(bundleList[0].metadata.bundleIdentifier == bundleInfo[0].1)
        
        #expect(bundleList[1].metadata.displayName == bundleInfo[1].0)
        #expect(bundleList[1].metadata.bundleIdentifier == bundleInfo[1].1)
    }
    
    @Test
    func removeBundle() async throws {
        let app = try await server.application()
        
        let bundle = await repo.addBundle(
            displayName: "DocumentationKit",
            identifier: "com.example.DocumentationKit"
        )
        
        print(bundle.id, await repo.bundleMap)

        try await #require(repo.bundleMap.count == 1)
        
        try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            try await repository.removeBundle(bundle.id)
        }
        
        await #expect(repo.bundleMap.count == 0)
    }
    
    @Test
    func addRevision() async throws {
        let app = try await server.application()
        
        let bundleId = await repo.addBundle(
            displayName: "DocumentationKit",
            identifier: "com.example.DocumentationKit"
        ).id
        
        let source = URL(filePath: "/")
        let (tag1, tag2) = ("1.0.0", "2.0.0")
        
        try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            
            for tag in [tag1, tag2] {
                let returnedRevision = try await repository.addRevision(
                    tag, source: source,
                    toBundle: bundleId
                )
                
                #expect(returnedRevision.tag == tag)
                #expect(returnedRevision.source == source)
                #expect(returnedRevision.bundleId == bundleId)
            }
        }
        
        let revisions = try await #require(repo.bundleRevisions[bundleId])
        
        let revision1 = try #require(revisions[tag1])
        #expect(revision1.tag == tag1)
        #expect(revision1.source == source)
        #expect(revision1.bundleId == bundleId)
        
        let revision2 = try #require(revisions[tag2])
        #expect(revision2.tag == tag2)
        #expect(revision2.source == source)
        #expect(revision2.bundleId == bundleId)
    }
    
    @Test
    func getRevision() async throws {
        let app = try await server.application()
        
        let bundleId = await repo.addBundle(
            displayName: "DocumentationKit",
            identifier: "com.example.DocumentationKit"
        ).id
        
        let revision = try await repo.addRevision(
            "1.0.0",
            source: URL(filePath: "/"),
            toBundle: bundleId
        )
        
        let returnedRevisionOpt = try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            return try await repository.revision(revision.tag, forBundle: bundleId)
        }
        
        let returnedRevision = try #require(returnedRevisionOpt)
        
        #expect(returnedRevision.id == revision.id)
        #expect(returnedRevision.tag == revision.tag)
        #expect(returnedRevision.source == revision.source)
        #expect(returnedRevision.bundleId == revision.bundleId)
    }
    
    @Test
    func removeRevision() async throws {
        let app = try await server.application()
        
        let bundleId = await repo.addBundle(
            displayName: "DocumentationKit",
            identifier: "com.example.DocumentationKit"
        ).id
        
        let revision = try await repo.addRevision(
            "1.0.0",
            source: URL(filePath: "/"),
            toBundle: bundleId
        )

        try await #require(repo.bundleRevisions[bundleId]?.count == 1)
        
        try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            try await repository.removeRevision(revision.tag, forBundle: bundleId)
        }
        
        try await #require(repo.bundleRevisions[bundleId]?.count == 0)
    }
    
    @Test(arguments: [
        (nil, true),
        ("Docu", true),
        ("documentationkit", true),
        ("docu", true),
        ("kit", true),
        ("ki", true),
        ("inval", false),
    ])
    func searchTest(
        term: String?,
        shouldFind: Bool
    ) async throws {
        let app = try await server.application()
        
        try await app.test(.router) { client in
            let repository = HTTPDocumentationRepository(client: client)
            
            let displayName = "DocumentationKit"
            let bundleIdentifier = "com.example.DocumentationKit"

            let createdBundle = try await repository.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            )

            try #require(try await repository.bundle(createdBundle.id) != nil)
            let results = try await repository.search(query: .init(term: term))
            #expect(results.count == 1)
            #expect(results.first == createdBundle)
        }
    }
}
