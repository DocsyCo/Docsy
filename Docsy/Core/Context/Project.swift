//
//  Project.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import Foundation

class Project: CustomStringConvertible {
    var description: String { "Project(\(identifier))" }

    private(set) var isPersistent: Bool = false

    let identifier: String
    var displayName: String
    var items: [Node]
    var references: [BundleIdentifier: Reference]

    /// Creates a transient project (one that cannot be persisted)
    /// - Parameter displayName: Display Name
    /// - Returns: A Transient Project
    static func transient(displayName: String = "") -> Project {
        Project(displayName: displayName, items: [], references: [:])
    }

    init(
        identifier: String = UUID().uuidString,
        displayName: String,
        items: [Node],
        references: [BundleIdentifier: Reference]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.items = items
        self.references = references
    }

    func persist() async throws {
        fatalError("if isPersistent is true, you must implement persist")
    }

    struct ValidationFailure: Error {
        let missingReferences: [String]
        let unusedReferences: [String]
    }

    func validate() throws(ValidationFailure) {
        var missingReferences = [String]()
        var unusedReferences = Set(references.keys)

        for item in items {
            guard let rootReference = item.reference?.bundleIdentifier else {
                continue
            }

            if references.keys.contains(rootReference) {
                unusedReferences.remove(rootReference)
            } else {
                missingReferences.append(rootReference)
            }
        }

        guard missingReferences.isEmpty, unusedReferences.isEmpty else {
            throw ValidationFailure(
                missingReferences: missingReferences,
                unusedReferences: Array(unusedReferences)
            )
        }
    }
}

// MARK: Node

extension Project {
    /// A node in a Workspace's navigator
    struct Node: Codable {
        let displayName: String
        let reference: DocumentationURI?
    }
}

// MARK: Bundle

extension Project {
    struct Reference: Codable {
        let source: Source
        let metadata: DocumentationBundle.Metadata
        var bundleIdentifier: BundleIdentifier {
            metadata.identifier
        }

        var displayName: String {
            metadata.displayName
        }

        func bundle() -> DocumentationBundle {
            switch source {
            case .http(let httpSource):
                DocumentationBundle(
                    info: metadata,
                    indexPath: String(httpSource.indexUrl.absoluteString
                        .trimmingPrefix(httpSource.baseURL.absoluteString))
                )
            case .localFS(let localSource):
                DocumentationBundle(
                    info: metadata,
                    indexPath: "/index"
                )
            default: fatalError("Unavailable for kind '\(source.kind)'")
            }
        }
    }
}

// MARK: Source

extension Project {
    enum Source: Sendable {
        case localFS(LocalFS)
        case index(DocSeeIndex)
        case http(HTTP)

        var kind: Kind {
            switch self {
            case .localFS: .localFS
            case .index: .index
            case .http: .http
            }
        }

        enum Kind: String, Codable {
            case localFS
            case index
            case http
        }

        struct DocSeeIndex: Codable {
            let path: String
        }

        struct LocalFS: Codable, Sendable {
            let rootURL: URL
        }

        struct HTTP: Codable, Sendable {
            let baseURL: URL
            let indexUrl: URL

            init(baseURL: URL, indexUrl: URL) {
                self.baseURL = baseURL
                self.indexUrl = indexUrl
            }

            init(baseURL: URL, indexPath: String) {
                self.baseURL = baseURL
                self.indexUrl = baseURL.appending(path: indexPath)
            }
        }
    }
}

extension Project.Source: Codable {
    enum CodingKeys: CodingKey {
        case kind
        case config
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)

        let config: any Encodable = switch self {
        case .localFS(let localFS): localFS
        case .index(let docSeeIndex): docSeeIndex
        case .http(let http): http
        }

        try container.encode(config, forKey: .config)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let kind = try container.decode(Kind.self, forKey: .kind)

        self = switch kind {
        case .localFS:
            try .localFS(container.decode(LocalFS.self, forKey: .config))
        case .index:
            try .index(container.decode(DocSeeIndex.self, forKey: .config))
        case .http:
            try .http(container.decode(HTTP.self, forKey: .config))
        }
    }
}

// MARK: DataProvider

struct ProjectSourceDataProvider: BundleRepositoryProvider {
    let source: Project.Source

    init(_ source: Project.Source) {
        self.source = source
    }

    func data(for path: String) async throws -> Data {
        switch source {
        case .http(let httpSource):
            let url = httpSource.baseURL.appending(path: path)
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        default: fatalError("Unavailable for kind '\(source.kind)'")
        }
    }
}
