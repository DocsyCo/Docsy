//
//  Migrations.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import GRDB

struct DocumentationRepositoryIndexRecord: Codable, PersistableRecord, FetchableRecord {
    static let databaseTableName: String = "search"
}

func registerMigrations(onMigrator migrator: inout DatabaseMigrator) {
    migrator.registerMigration("createBundleTable") { db in
        try db.create(table: BundleMetadata.databaseTableName) { t in
            t.column("id").unique().primaryKey()
            t.column("displayName", .text)
            t.column("bundleIdentifier", .text).unique().notNull()
        }
    }

    migrator.registerMigration("createRevisionsTable") { db in
        try db.create(table: BundleRevision.databaseTableName) { t in
            t.column("bundleId").references(BundleMetadata.databaseTableName).notNull()
            t.column("tag", .text).notNull()
            t.column("source", .text).notNull()
            t.uniqueKey(["bundleId", "tag"])
        }
    }

    migrator.registerMigration("createSearchIndex") { db in
        try db.create(
            virtualTable: DocumentationRepositoryIndexRecord.databaseTableName,
            using: FTS5()
        ) { t in
            t.synchronize(withTable: BundleMetadata.databaseTableName)
            t.tokenizer = CamelCaseTokenizer.tokenizerDescriptor()
            t.column("displayName")
            t.column("bundleIdentifier")
        }
    }
}

import SQLite3

final class CamelCaseTokenizer: FTS5CustomTokenizer {
    static let name = "camelcase"
    let finalizer: any FTS5Tokenizer

    init(db: Database, arguments: [String]) throws {
        self.finalizer = try db.makeTokenizer(.porter())
    }

    func finalize(
        context: UnsafeMutableRawPointer?,
        tokenization: FTS5Tokenization,
        pText: UnsafePointer<CChar>?,
        nText: CInt,
        tokenCallback: FTS5TokenCallback
    ) -> CInt {
        finalizer.tokenize(
            context: context,
            tokenization: tokenization,
            pText: pText,
            nText: nText,
            tokenCallback: tokenCallback
        )
    }

    func tokenize(
        context: UnsafeMutableRawPointer?,
        tokenization: FTS5Tokenization,
        pText: UnsafePointer<CChar>?,
        nText: CInt,
        tokenCallback: FTS5TokenCallback
    ) -> CInt {
        guard let pText else { return SQLITE_OK }

        let text = String(cString: pText)
        let camelCaseTokens = Self.splitPreTokens(text)

        guard !camelCaseTokens.isEmpty else { return SQLITE_OK }

        // Tokenize each camel case component
        for token in camelCaseTokens {
            let result = token.withCString { pToken in
                finalize(
                    context: context,
                    tokenization: tokenization,
                    pText: pToken,
                    nText: nText,
                    tokenCallback: tokenCallback
                )
            }

            if result != SQLITE_OK {
                return result
            }
        }

        return SQLITE_OK
    }

    static func splitPreTokens(_ input: String) -> [String] {
        let regex = /(?:[\.,\s]|^)([a-z]*?(?:[A-Z][a-z,0-9]+)+)/
        var matches = input.matches(of: regex).makeIterator()

        var output = [String]()
        var currentIndex: String.Index = input.startIndex

        while let match = matches.next() {
            defer { currentIndex = match.range.upperBound }
            if match.range.lowerBound < currentIndex {
                output.append(String(input[currentIndex..<match.range.lowerBound]))
            }

            let splitText = match.output.1.splitCamelCase()
            output.append(contentsOf: splitText)
        }

        if currentIndex < input.endIndex {
            let fullTextSuffix = String(input[currentIndex..<input.endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !fullTextSuffix.isEmpty {
                output.append(fullTextSuffix)
            }
        }

        return output
    }
}

extension StringProtocol {
    func splitCamelCase() -> [String] {
        unicodeScalars.reduce(into: [String]()) { result, scalar in
            if scalar.properties.isUppercase, !result.isEmpty {
                result.append(String(scalar).lowercased())
            } else if result.endIndex > 0 {
                result[result.endIndex - 1].append(String(scalar).lowercased())
            } else {
                result.append(String(scalar).lowercased())
            }
        }
    }
}
