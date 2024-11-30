//
//  Project.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

//
//  DocsyTests.swift
//  DocsyTests
//
//  Created by Noah Kamara on 19.11.24.
//
@testable import Docsy
import DocumentationKit
import Foundation
import Testing

class MockProject: Project {
    private let _isPersistent: Bool
    override var isPersistent: Bool { _isPersistent }
    var onPersist: (() -> Void)? = nil

    init(
        isPersistent: Bool = false,
        identifier: String = UUID().uuidString,
        displayName: String = UUID().uuidString,
        items: [Project.Node] = [],
        references: [BundleIdentifier: Project.Reference] = [:]
    ) {
        self._isPersistent = isPersistent
        super.init(displayName: displayName, items: items, references: references)
    }

    override func persist() async throws {
        onPersist?()
    }
}

extension Workspace.Configuration {
    static let test = Self(inMemory: true)
}

extension Tag {
    @Tag static var contextPlugin: Self
}

@Suite("Plugin: Metadata", .tags(.contextPlugin))
struct WorkspaceMetadataTests {
    @Test
    func loading() async throws {
        let project = MockProject(isPersistent: true)
        let workspace = try Workspace(config: .test)
        let metadata = workspace.metadata

        try await workspace.open(project)

        // metadata was set
        await #expect(metadata.identifier == project.identifier)
        await #expect(metadata.displayName == project.displayName)
    }

    @Test
    func saving() async throws {
        let originalDisplayName = UUID().uuidString
        let project = MockProject(isPersistent: true, displayName: originalDisplayName)

        let workspace = try Workspace(config: .test)
        try await workspace.open(project)
        let metadata = workspace.metadata

        let newDisplayName = UUID().uuidString

        await metadata.setDisplayName(newDisplayName)

        // Metadata was set
        await #expect(metadata.displayName == newDisplayName)

        // project still has old displayName before save
        #expect(project.displayName == originalDisplayName)

        // persist() is called while saving
        try await confirmation { confirm in
            project.onPersist = { confirm() }
            try await workspace.save()
        }

        // project still has new displayName after safe
        #expect(project.displayName == newDisplayName)
    }
}

extension Project.Reference {
    static var testExample: Self {
        let rootURL = URL(
            filePath: "/Users/noahkamara/Developer/DocSee/DocCServer/data/docsee/SlothCreator/data/documentation/slothcreator"
        )

        return Project.Reference(
            source: .localFS(.init(rootURL: rootURL)),
            metadata: .init(displayName: "slothcreator", identifier: "SlothCreator")
        )
    }
}

@Suite("Plugin: BundleRepository", .tags(.contextPlugin))
struct BundleRepositoryTests {
    @Test
    func loading() async throws {
        let projectBundle = Project.Reference.testExample

        let project = MockProject(
            isPersistent: true,
            items: [
                .bundle(.init(displayName: projectBundle.displayName, bundleIdentifier: projectBundle.bundleIdentifier)),
            ],
            references: [projectBundle.bundleIdentifier: projectBundle]
        )

        let workspace = try Workspace(config: .test)
        let repo = workspace.bundleRepository

        // should be empty when initialized
        #expect(await repo.isEmpty)

        try await workspace.open(project)

        // should now contain exactly one providera
        let repoCount = await repo.count
        #expect(repoCount == 1)

        let repoBundle = try #require(await repo.bundle(with: projectBundle.bundleIdentifier))

        // bundle was correctly injested
        #expect(repoBundle.displayName == projectBundle.displayName)
        #expect(repoBundle.identifier == projectBundle.bundleIdentifier)
    }

    @Test
    func saving() async throws {
        let project = MockProject(
            isPersistent: true,
            references: [:]
        )

        let workspace = try Workspace(config: .test)
        let repo = workspace.bundleRepository

        try await workspace.open(project)

        // should be empty when initialized
        #expect(await repo.isEmpty)

        let addedBundle = Project.Reference.testExample
//        workspace.addBundle(addedBundle)

        // saving
        try await confirmation { confirm in
            project.onPersist = { confirm() }
            try await workspace.save()
        }

        await withKnownIssue {
            // should now contain exactly one providera
            let repoCount = await repo.count
            #expect(repoCount == 1)

            let repoBundle = try #require(await repo.bundle(with: addedBundle.bundleIdentifier))

            // bundle was correctly added
            #expect(repoBundle.displayName == addedBundle.displayName)
            #expect(repoBundle.identifier == addedBundle.bundleIdentifier)
        }
    }
}

@Suite("Plugin: Navigator", .tags(.contextPlugin))
struct NavigatorTests {
    @Test
    func loading() async throws {
        let projectBundle = Project.Reference.testExample

        let project = MockProject(
            isPersistent: true,
            items: [.bundle(.init(
                displayName: projectBundle.displayName,
                bundleIdentifier: projectBundle.bundleIdentifier
            ))],
            references: [projectBundle.bundleIdentifier: projectBundle]
        )
        try #require(try project.validate())

        let workspace = try Workspace(config: .test)
        try await workspace.open(project)
        let nav = workspace.navigator

        /// Top level nodes should be available immediately
        #expect(await nav.nodes.count == project.references.count)

        /// Indices should be created but we dont know if we can access them yet
        #expect(await nav.indices.count == project.references.count)

        var loadingNodes = await nav.nodes

        await print("INITIAL LOADING", loadingNodes, nav.nodes)
        while !loadingNodes.isEmpty {
            print("\(loadingNodes.count) nodes loading...")

            try await Task.sleep(for: .milliseconds(300))

            let oldNodes = loadingNodes
            loadingNodes = await MainActor.run {
                oldNodes.filter(\.isLoading)
            }
        }

        print("done loading")

        let topLevelId = try #require(nav.indices.keys.first)

        let path = await nav.path(for: .init(topLevelId: topLevelId, nodeId: 1))

        #expect(path == "")
//
//        // should be empty when initialized
//        #expect(await repo.isEmpty)
//
//        try await workspace.open(project)
//
//        // should now contain exactly one providera
//        let repoCount = await repo.count
//        #expect(repoCount == 1)
//
//        let repoBundle = try #require(await repo.bundle(with: projectBundle.bundleIdentifier))
//
//        // bundle was correctly injested
//        #expect(repoBundle.displayName == projectBundle.displayName)
//        #expect(repoBundle.identifier == projectBundle.bundleIdentifier)
    }

//    @Test
//    func saving() async throws {
//        let project = MockProject(
//            isPersistent: true,
//            references: [:]
//        )
//
//        let workspace = try Workspace(config: .test)
//        let repo = workspace.bundleRepository
//
//        try await workspace.open(project)
//
//        // should be empty when initialized
//        #expect(await repo.isEmpty)
//
//        let addedBundle = Project.Bundle.testExample
    ////        workspace.addBundle(addedBundle)
//
//
//        // saving
//        try await confirmation { confirm in
//            project.onPersist = { confirm() }
//            try await workspace.save()
//        }
//
//        await withKnownIssue {
//            // should now contain exactly one providera
//            let repoCount = await repo.count
//            #expect(repoCount == 1)
//
//            let repoBundle = try #require(await repo.bundle(with: addedBundle.bundleIdentifier))
//
//            // bundle was correctly added
//            #expect(repoBundle.displayName == addedBundle.displayName)
//            #expect(repoBundle.identifier == addedBundle.bundleIdentifier)
//        }
//    }
}
