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

    let repository: DocumentationRepository

    @MainActor
    var searchTerm: String = "" {
        didSet { update() }
    }

    init(repository: DocumentationRepository) {
        self.repository = repository
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

        observationTask = Task {
            let items = try await self.repository.search(query: .init(term: term))

            await MainActor.run {
                self.items = items
            }
        }
    }
}
