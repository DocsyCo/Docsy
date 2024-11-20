//
//  Project.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation

typealias BundleIdentifier = String

class Project {
    private(set) var isPersistent: Bool = false
    
    let identifier: String
    var displayName: String
    var items: [Node]
    var references: [BundleIdentifier: Bundle]
    
    init(
        identifier: String = UUID().uuidString,
        displayName: String,
        items: [Node],
        references: [BundleIdentifier : Bundle]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.items = items
        self.references = references
    }
    
    func persist() async throws {
        fatalError("if isPersistent is true, you must implement persist")
    }
    
    // MARK: Bundle
    struct Bundle: Codable {
        let source: DocumentationSource
        let bundleIdentifier: BundleIdentifier
        let displayName: String
    }

    // MARK: Node

    /// A node in a DocumentationWorkspace's navigator
    struct Node: Codable {
        enum Kind: Codable {
            case bundle
            case groupMarker
        }
        
        let kind: Kind
        let displayName: String
        let reference: String?
        
        private init(kind: Kind, displayName: String, reference: String?) {
            self.kind = kind
            self.displayName = displayName
            self.reference = reference
        }
        
        static func groupMarker(title: String) -> Node {
            Node(kind: .groupMarker, displayName: title, reference: nil)
        }
        
        static func bundle(displayName: String, identifier: BundleIdentifier) -> Node {
            Node(
                kind: .bundle,
                displayName: displayName,
                reference: identifier
            )
        }
    }
    
}


enum DocumentationSource: Sendable {
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

// MARK: Codable
extension DocumentationSource: Codable {
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
            try .localFS(container.decode(DocumentationSource.LocalFS.self, forKey: .config))
        case .index:
            try .index(container.decode(DocumentationSource.DocSeeIndex.self, forKey: .config))
        case .http:
            try .http(container.decode(DocumentationSource.HTTP.self, forKey: .config))
        }
    }
}
