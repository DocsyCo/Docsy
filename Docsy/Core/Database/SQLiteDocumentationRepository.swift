//
//  SQLiteDocumentationRepository.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import GRDB

// struct DocumentationRepositoryIndexRecord: Codable, FetchableRecord, PersistableRecord {
//    static var databaseTableName: String = BundleMetadata.databaseTableName+"_fts"
//
//    let content:
// }

extension BundleMetadata {
    static let records = hasOne(DocumentationRepositoryIndexRecord.self, key: "rowid")
}

extension DocumentationRepositoryIndexRecord {
    static let bundle = hasOne(BundleMetadata.self, key: "rowid")
}

struct SQLiteDocumentationRepository: DocumentationRepository {
    private let database: DatabaseWriter

    init(database: DatabaseWriter) {
        self.database = database
    }

    enum SearchError: Error {
        case couldNotBuild
    }

    // MARK: Bundles

    func search(query: BundleQuery) async throws -> [BundleDetail] {
        guard let term = query.term, !term.isEmpty else {
            return try await database.read { db in
                try BundleMetadata.all().detail().fetchAll(db)
            }
        }

        let preTokenizedTerm = CamelCaseTokenizer.splitPreTokens(term).joined(separator: " ")

        guard let pattern = FTS5Pattern(matchingAllPrefixesIn: preTokenizedTerm) else {
            throw SearchError.couldNotBuild
        }

        let sql = """
        SELECT 
            \(BundleMetadata.databaseTableName).*, 
            json_group_array(
                json_object(
                  'source', revisions.source,
                  'tag', revisions.tag
                )
            ) AS revisions
        FROM \(BundleMetadata.databaseTableName)
        INNER JOIN \(DocumentationRepositoryIndexRecord.databaseTableName)
            ON \(DocumentationRepositoryIndexRecord.databaseTableName).rowid = \(BundleMetadata.databaseTableName).rowid
            AND \(DocumentationRepositoryIndexRecord.databaseTableName) MATCH ?
        INNER JOIN revisions ON revisions.bundleId = \(BundleMetadata.databaseTableName).id
        GROUP BY bundles.id
        HAVING \(BundleMetadata.databaseTableName).id IS NOT NULL
        """

        return try await database.read { db in
            do {
                let res = try BundleDetail.fetchAll(db, sql: sql, arguments: [pattern])
                return res
            } catch {
                print("REQUEST FAILED", error)
                try print("ROWS", Row.fetchAll(db, sql: sql, arguments: [pattern]).first)
                throw error
            }
        }
    }

    func searchCompletions(for prefix: String, limit: Int) async throws -> [String] {
        try await database.read { db in
            let sql = """
                SELECT DISTINCT term
                FROM \(DocumentationRepositoryIndexRecord.databaseTableName)_data
                WHERE term MATCH ?
                ORDER BY rank
                LIMIT ?
            """
            let pattern = FTS5Pattern(matchingAllPrefixesIn: prefix)
            return try String.fetchAll(db, sql: sql, arguments: [pattern, limit])
        }
    }

    func addBundle(displayName: String, identifier: String) async throws -> BundleDetail {
        let metadata = BundleMetadata(
            id: UUID(),
            displayName: displayName,
            bundleIdentifier: identifier
        )

        try await database.write { db in
            try metadata.insert(db)
        }

        return BundleDetail(metadata: metadata, revisions: [])
    }

    func bundle(_ bundleId: BundleMetadata.ID) async throws -> BundleDetail? {
        let request = BundleMetadata.filter(id: bundleId).detail()

        return try await database.read { db in
            try BundleDetail.fetchOne(db, request)
        }
    }

    func removeBundle(_ bundleId: BundleMetadata.ID) async throws {
        _ = try await database.write { db in
            try BundleMetadata.deleteOne(db, id: bundleId)
        }
    }

    func addRevision(
        _ tag: BundleRevision.Tag,
        source: URL,
        toBundle bundleId: BundleMetadata.ID
    ) async throws -> BundleRevision {
        let revision = BundleRevision(bundleId: bundleId, tag: tag, source: source)

        try await database.write { db in
            try revision.insert(db)
        }

        return revision
    }

    func revision(
        _ tag: BundleRevision.Tag,
        forBundle bundleId: BundleMetadata.ID
    ) async throws -> BundleRevision? {
        try await database.read { db in
            try BundleRevision
                .filter(Column("bundleId") == bundleId)
                .filter(Column("tag") == tag)
                .fetchOne(db)
        }
    }

    func removeRevision(_ tag: BundleRevision.Tag, forBundle bundleId: BundleMetadata.ID) async throws {
        _ = try await database.write { db in
            try BundleRevision
                .filter(Column("bundleId") == bundleId)
                .filter(Column("tag") == tag)
                .deleteAll(db)
        }
    }
}

import SwiftUI

extension EnvironmentValues {
    @Entry var documentationRepo: any DocumentationRepository = InMemoryDocumentationRepository()
}

struct PreviewDocumentationRepository: PreviewModifier {
    typealias Context = DocumentationRepository

    static func createPreviewBundles(_ repo: DocumentationRepository) async throws {
        let bundleData: [String: (String, [String])] = [
            "app.getdocsy.documentationkit": ("DocumentationKit", ["0.1.0", "0.1.1", "0.2.0"]),
            "app.getdocsy.documentationServer": ("DocumentationServer", ["0.1.0", "0.1.1", "0.1.2", "0.2.0"]),
        ]

        for (bundleIdentifier, (displayName, revisions)) in bundleData {
            let bundle = try await repo.addBundle(
                displayName: displayName,
                identifier: bundleIdentifier
            )

            for revision in revisions {
                _ = try await repo.addRevision(
                    revision,
                    source: URL(filePath: "/" + bundle.id.uuidString + "/" + revision),
                    toBundle: bundle.id
                )
            }
        }
    }

    static func makeSharedContext() async throws -> Context {
        let queue = try DatabaseQueue()
        let repo = SQLiteDocumentationRepository(database: queue)

        var migrator = DatabaseMigrator()
        registerMigrations(onMigrator: &migrator)
        try migrator.migrate(queue)

        try await createPreviewBundles(repo)

        return repo
    }

    func body(content: Content, context: Context) -> some View {
        content
            .environment(\.documentationRepo, context)
    }
}

// extension PreviewModifier where Self: PreviewTrait {
//
// }
//

struct EnvironmentValueView<Content: View, Value>: View {
    @Environment
    var value: Value

    var content: (Value) -> Content

    init(
        _ key: KeyPath<EnvironmentValues, Value>,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self._value = Environment(key)
        self.content = content
    }

    var body: some View {
        content(value)
    }
}

//#Preview(traits: .modifier(PreviewDocumentationRepository())) {
//    EnvironmentValueView(\.documentationRepo) { repository in
//        DocumentationBrowserView(.init(repos: [
//            .local: repository,
//            .cloud: repository
//        ]))
//        .frame(width: 400, height: 300)
//    }
//}

// MARK: Model Extension

extension BundleMetadata: @retroactive MutablePersistableRecord {}
extension BundleMetadata: @retroactive TableRecord {}
extension BundleMetadata: @retroactive EncodableRecord {}
extension BundleMetadata: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName: String = "bundles"
    static let revisions = hasMany(BundleRevision.self)
}

extension BundleRevision: @retroactive MutablePersistableRecord {}
extension BundleRevision: @retroactive TableRecord {}
extension BundleRevision: @retroactive EncodableRecord {}
extension BundleRevision: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName: String = "revisions"
    static let bundle = belongsTo(BundleMetadata.self)
}

extension BundleDetail.Revision: @retroactive MutablePersistableRecord {}
extension BundleDetail.Revision: @retroactive TableRecord {}
extension BundleDetail.Revision: @retroactive EncodableRecord {}
extension BundleDetail.Revision: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName: String = BundleRevision.databaseTableName
    static let bundle = belongsTo(BundleMetadata.self)
}

extension BundleDetail: @retroactive FetchableRecord {}

extension QueryInterfaceRequest<BundleMetadata> {
    func detail() -> QueryInterfaceRequest<BundleDetail> {
        including(all: BundleMetadata.revisions)
            .asRequest(of: BundleDetail.self)
    }
}
