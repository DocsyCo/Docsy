//
//  DocsyApp.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import GRDB
import SwiftUI

import DocumentationServerClient

/// # Todo
/// - [ ] Bundle Import
///     - [ ] Import local filesystem (copy to internal path)
///     - [ ] Import from URL
///     - [ ] Import from server
/// - [x] Bundle Repository server
/// - [x] Add bundle from repo to workspace
/// - [ ] Storage server
/// - [ ] allow adding group markers (and reorder)
/// - [ ] Workspace persistence
///     - [ ] bundles
///     - [ ] navigator-order
///     - [ ] metadata (title)
/// - [ ] custom theme settings (future idea -> customizable?)

@main
struct DocsyApp: App {
    let repositories: DocumentationRepositories = DocumentationRepositories(repos: [
        .cloud: HTTPDocumentationRepository(baseURI: URL(string: "http://127.0.0.1:1234")!)
    ])
    
    // MARK: Multiwindow
#if os(macOS)
    let supportsWindows: Bool = true
#else
    @Environment(\.supportsMultipleWindows)
    private var supportsMultipleWindows
    
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
    
    var supportsWindows: Bool {
        supportsMultipleWindows && (
            horizontalSizeClass == .compact || verticalSizeClass == .compact
        )
    }
#endif
    
    let workspace = try! Workspace(config: .init(inMemory: true))
    
    var body: some Scene {
        MainWindow(workspace: workspace, repositories: repositories)
        BundleBrowserWindow(workspace: workspace, repositories: repositories)
    }
}

extension DocumentationRepositories {
    static func preview() -> DocumentationRepositories {
        let localRepository: any DocumentationRepository = {
            let documentationKit = BundleMetadata(
                id: UUID(),
                displayName: "DocumentationKit",
                bundleIdentifier: "app.getdocsy.documentationkit"
            )
            
            let documentationServer = BundleMetadata(
                id: UUID(),
                displayName: "DocumentationServer",
                bundleIdentifier: "app.getdocsy.documentationServer"
            )
            
            return InMemoryDocumentationRepository(
                bundles: [documentationKit, documentationServer],
                revisions: [
                    documentationKit.id: [
                        "0.1.0": URL(filePath: "/" + UUID().uuidString),
                        "0.1.1": URL(filePath: "/" + UUID().uuidString),
                    ],
                    documentationServer.id: [
                        "0.1.0": URL(filePath: "/" + UUID().uuidString),
                        "0.1.1": URL(filePath: "/" + UUID().uuidString),
                        "0.1.2": URL(filePath: "/" + UUID().uuidString),
                    ],
                ]
            )
        }()
        
        return .init(repos: [
            .local: localRepository,
            .cloud: HTTPDocumentationRepository(baseURI: URL(string: "http://127.0.0.1:1234")!)
        ])
    }
}


extension Project {
    static func scratchpad() -> Project {
        Project(displayName: "Scratchpad", items: [], references: [:])
    }
}

struct ApplicationDB {
    private let queue: DatabaseQueue

    private static func makeConfig() -> Configuration {
        var config = Configuration()
        config.prepareDatabase { db in
            db.add(tokenizer: CamelCaseTokenizer.self)
        }
        return config
    }

    init(path: String) throws {
        let queue = try DatabaseQueue(path: path, configuration: Self.makeConfig())
        try self.init(queue: queue)
    }

    init() throws {
        let queue = try DatabaseQueue(configuration: Self.makeConfig())
        try self.init(queue: queue)
    }

    private init(queue: DatabaseQueue) throws {
        self.queue = queue

        var migrator = DatabaseMigrator()
        registerMigrations(onMigrator: &migrator)

        try migrator.migrate(queue)
    }

    var documentation: DocumentationRepository {
        SQLiteDocumentationRepository(database: queue)
    }
}


