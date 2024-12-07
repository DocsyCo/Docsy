//
//  DocsyApp.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import GRDB
import SwiftUI

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

@main
struct DocsyApp: App {
    @State
    var db: ApplicationDB? = nil

    @State
    var isLoaded: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let db {
                    DocumentationBrowserView(repository: db.documentation)
                } else {
                    ProgressView()
                }
            }
            .task {
                guard db == nil else { return }
                do {
                    let databaseURL = URL.temporaryDirectory.appending(component: "testdb")
                    print("DATABASEURL", databaseURL.path())
                    let db = try ApplicationDB()

                    print(URL.temporaryDirectory.appending(component: "testdb"))
                    try? await PreviewDocumentationRepository.createPreviewBundles(db.documentation)

                    self.db = db
                } catch {
                    print("HO", error)
                }
            }
        }
    }
}
