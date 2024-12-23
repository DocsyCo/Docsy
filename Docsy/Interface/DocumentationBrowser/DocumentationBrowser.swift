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
    
    let repositories: DocumentationRepositories

    @MainActor
    var searchTerm: String = "" {
        didSet { update() }
    }
    
    @MainActor
    var scope: Scope = .local {
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
        let scope = scope
        
        print("Update", scope, term)
        
        observationTask = Task {
            guard let repository = repositories[scope] else {
                await MainActor.run {
                    self.items = []
                }
                return
            }
            
            let items = try await repository.search(query: .init(term: term))

            await MainActor.run {
                self.items = items
            }
        }
    }
}

@MainActor
@Observable
class DocumentationRepositories {
    typealias Scope = DocumentationBrowser.Scope
    private var repos: [Scope: DocumentationRepository] = [:]
    
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

