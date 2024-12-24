//
//  DocumentationBrowser.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import Foundation

@Observable
class DocumentationBrowser: Identifiable {
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
        let scopes = scopes
        
        print("Update", scopes, term)
        
        observationTask = Task {
            let items = try await withThrowingTaskGroup(of: (Scope, [BundleDetail]).self) { tasks in
                for scope in scopes {
                    guard let repository = repositories[scope] else {
                        print("could not find repository for scope '\(scope)'")
                        continue
                    }
                    
                    tasks.addTask {
                        let results = try await repository.search(query: .init(term: term))
                        return (scope, results)
                    }
                }
                
                var results: [Scope:[Item]] = [:]
                
                for try await (scope, items) in tasks {
                    results[scope] = items
                }
                
                return results.sorted(by: { $0.key < $1.key }).flatMap(\.value)
            }

            await MainActor.run {
                self.items = items
            }
        }
    }
}


extension DocumentationBrowser {
    struct Scope: Hashable, Comparable {
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

