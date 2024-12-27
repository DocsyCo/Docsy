//
//  DocumentationBrowser.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import Foundation
import OSLog

@Observable
class DocumentationBrowser: Identifiable {
    let logger = Logger.docsee("DocumentationBrowser")
    typealias Item = BundleDetail
    
    let repositories: DocumentationRepositories

    @MainActor
    var searchTerm: String = "" {
        didSet { update() }
    }
    
    @MainActor
    var scopes: Set<Scope> = [.local, .cloud] {
        didSet { update() }
    }

    init(
        repositories: DocumentationRepositories
    ) {
        self.repositories = repositories
    }

    @MainActor
    private(set) var items: [Item] = []

    @MainActor
    private var observationTask: Task<Void, any Error>? = nil

    func bootstrap() async throws {
        await update()

        guard let task = await observationTask, !task.isCancelled else {
            return
        }

        try await task.value
    }

    @MainActor
    private func update() {
        observationTask?.cancel()
        let term = searchTerm
        let scopes = scopes.isEmpty ? .all : scopes
        
        observationTask = Task<Void, any Error> {
            let logger = self.logger
            let query = DocumentationRepositoryBundleQuery(term: term)
            
            let items = await searchRepositories(
                query: query,
                scopes: scopes,
                repositories: repositories,
                logger: logger
            )

            await MainActor.run {
                self.items = items
            }
        }
    }
}

extension DocumentationBrowser {
    struct Scope: Hashable, Comparable, CustomStringConvertible {
        var description: String { "Scope(\(identifier)" }
        let identifier: String
        
        static let local = Scope("local")
        static let cloud = Scope("cloud")

        init(_ identifier: String) {
            self.identifier = identifier
        }

        static func < (lhs: DocumentationBrowser.Scope, rhs: DocumentationBrowser.Scope) -> Bool {
            lhs.sortKey < rhs.sortKey
        }

        fileprivate var sortKey: String {
            switch self {
            case .local: "0"
            case .cloud: "1"
//            case .custom(let id): "2-\(id)"
            default: "9-"+identifier
            }
        }
    }
}

extension Set where Element == DocumentationBrowser.Scope {
    static let all: Self = [.local, .cloud]
}


typealias ScopedSearchResult = (
    DocumentationBrowser.Scope,
    Result<[DocumentationBrowser.Item], any Error>
)

@Sendable
fileprivate func searchRepositories(
    query: DocumentationRepositoryBundleQuery,
    scopes: Set<DocumentationBrowser.Scope>,
    repositories: DocumentationRepositories,
    logger: Logger
) async -> [DocumentationBrowser.Item] {
    return await withTaskGroup(
        of: ScopedSearchResult.self
    ) { tasks in
        for scope in scopes.sorted() {
            guard let repository = await repositories[scope] else {
                logger.error("could not find repository for scope '\(scope.identifier)'")
                continue
            }
            
            tasks.addTask {
                do {
                    let items = try await repository.search(query: query)
                    return (scope, .success(items))
                } catch {
                    return (scope, .failure(error))
                }
            }
        }
        
        var results: [DocumentationBrowser.Scope: [DocumentationBrowser.Item]] = [:]
        
        while let (scope, result) = await tasks.next() {
            switch result {
            case .success(let items):
                logger.info("DocumentationBrowser(\(scope)): found \(items.count) item")
                results[scope] = items
            case .failure(let error):
                if error is CancellationError {
                    logger.info("DocumentationBrowser(\(scope)): cancelled")
                } else {
                    logger.error("DocumentationBrowser(\(scope)): \(error)")
                }
            }
        }
        
        return Array(results.sorted(by: { $0.key < $1.key }).flatMap(\.value))
    }
}



@MainActor
@Observable
class DocumentationRepositories {
    typealias Scope = DocumentationBrowser.Scope
    private var repos: [Scope: DocumentationRepository] = [:]
    
    public var scopes: [Scope] { repos.keys.sorted() }
    
    subscript(_ scope: Scope) -> DocumentationRepository? {
        access(keyPath: \.repos)
        return repos[scope]
    }
    
    init(repos: [Scope : DocumentationRepository]) {
        self.repos = repos
    }
    
    func addRepository(_ repository: DocumentationRepository, as scope: Scope) {
        withMutation(keyPath: \.repos) {
            repos[scope] = repository
        }
    }
}

