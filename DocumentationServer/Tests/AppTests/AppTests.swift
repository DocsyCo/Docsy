import HummingbirdTesting
import Logging
import PostgresKit
import Testing
import Foundation

@testable import App

struct TestArguments: AppArguments {
    let inMemory: Bool = true
    let hostname = "127.0.0.1"
    let port = 0
    let logLevel: Logger.Level? = .trace
}


@Suite
struct AppTests {
    @Test
    func health() async throws {
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            try await client.execute(uri: "/health", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }
}

@Suite
struct RepositoryAPITests {
    @Test
    func createBundle() async throws {
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            let repository = TestRepository(client: client)
            
            let displayName = "DocumentationKit"
            let bundleIdentifier = "com.example.DocumentationKit"
            
            let bundle = try await repository.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            )

            let bundleList = try await repository.bundles()

            let firstBundle = try #require(bundleList.first)

            #expect(bundleList.count == 1)
            #expect(firstBundle == bundle)
        }
    }
    
    @Test
    func listBundles() async throws {
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            let repository = TestRepository(client: client)
            
            let initialBundleList = try await repository.bundles()
            #expect(initialBundleList.count == 0)
            
            let displayName = "DocumentationKit"
            let bundleIdentifier = "com.example.DocumentationKit"
            
            let bundle = try await repository.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            )
            
            let bundleList = try await repository.bundles()
            
            let firstBundle = try #require(bundleList.first)
            
            #expect(bundleList.count == 1)
            #expect(firstBundle == bundle)
        }
    }

    @inline(__always)
    func testRemoveBundle(repository: DocumentationRepository) async throws {
        let displayName = "DocumentationKit"
        let bundleIdentifier = "com.example.DocumentationKit"
        
        let bundle = try await repository.addBundle(
            displayName: displayName,
            identifier: bundleIdentifier
        )
        
        try #require(try await repository.bundles().count == 1)
        
        try await repository.removeBundle(bundle.id)
        #expect(try try await repository.bundles().count == 0)
    }
    
    @Test
    func removeBundle() async throws {
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            let repository = TestRepository(client: client)
            try await testRemoveBundle(repository: repository)
        }
    }
    
    @Test
    func addRevision() async throws {
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            let repository = TestRepository(client: client)
            
            let displayName = "DocumentationKit"
            let bundleIdentifier = "com.example.DocumentationKit"
            
            let bundleId = try await repository.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            ).id
            
            let tag1 = "1.0.0"
            let tag2 = "2.0.0"
            let source = URL(filePath: "/")
            
            for tag in [tag1, tag2] {
                let createdRevision = try await repository.addRevision(
                    tag, source: source,
                    toBundle: bundleId
                )
                
                #expect(createdRevision.tag == tag)
                #expect(createdRevision.source == source)
                
                let foundByTag = try await repository.revision(tag, forBundle: bundleId)
                #expect(foundByTag == createdRevision)
            }
            
            let bundle = try #require(try await repository.bundle(bundleId))
            try #require(bundle.revisions.count == 2)
            
            #expect(bundle.revisions.map(\.tag) == [tag1, tag2])
            #expect(bundle.revisions.map(\.source) == [source, source])
        }
    }
    
    @Test
    func removeRevision() async throws {
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            let repository = TestRepository(client: client)
            
            let displayName = "DocumentationKit"
            let bundleIdentifier = "com.example.DocumentationKit"

            let bundleId = try await repository.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            ).id

            let tag = "1.0.0"

            _ = try await repository.addRevision(
                tag,
                source: URL(filePath: "/"),
                toBundle: bundleId
            )

            try #require(try await repository.revision(tag, forBundle: bundleId) != nil)

            try await repository.removeRevision(tag, forBundle: bundleId)
            #expect(try await repository.revision(tag, forBundle: bundleId) == nil)
        }
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
        let app = try await buildApplication(TestArguments())
        
        try await app.test(.router) { client in
            let repository = TestRepository(client: client)
            
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



import DocumentationKit

import Hummingbird


import DocumentationKit


