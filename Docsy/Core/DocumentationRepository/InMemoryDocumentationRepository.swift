//
//  InMemoryDocumentationRepository.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

////
////  DocumentationRepository+InMemory.swift
////  DocSee
////
////  Created by Noah Kamara on 06.12.24.
////
//
// import Foundation
// import DocumentationKit
//
//// MARK: InMemory
// actor InMemoryDocumentationRepository: DocumentationRepository {
//    private(set) var bundleMap: [BundleMetadata.ID: BundleMetadata] = [:]
//    private(set) var bundleRevisions = [BundleMetadata.ID: [BundleRevision.Tag: BundleRevision]]()
//
//    init(
//        bundles: [BundleMetadata] = [],
//        revisions: [BundleMetadata.ID: [String: URL]] = [:]
//    ) {
//        self.bundleMap = Dictionary(uniqueKeysWithValues: bundles.map({ ($0.id, $0 )}))
//
//        self.bundleRevisions = Dictionary(uniqueKeysWithValues: revisions.map { bundleId, revisions in
//            let revisions = revisions.map({
//                ($0.key, BundleRevision(bundleId: bundleId, tag: $0.key, source: $0.value))
//            })
//
//            return ( bundleId, Dictionary(uniqueKeysWithValues: revisions))
//        })
//    }
//
//
//    // MARK: Bundles
//    func search(query: BundleQuery) -> [BundleDetail] {
//        var bundles = bundleMap
//            .sorted(by: { $0.value.displayName < $1.value.displayName })
//            .map(\.key)
//            .compactMap { self.bundle($0) }
//
//        if let term = query.term {
//            bundles.removeAll(where: { !$0.metadata.displayName.lowercased().contains(term) })
//        }
//
//        return bundles
//    }
//
//    func searchCompletions(for prefix: String, limit: Int) async throws -> [String] {
//        return []
//    }
//
//    func addBundle(displayName: String, identifier: String) -> BundleDetail {
//        let metadata = BundleMetadata(
//            id: UUID(),
//            displayName: displayName,
//            bundleIdentifier: identifier
//        )
//
//        bundleRevisions[metadata.id] = [:]
//        bundleMap[metadata.id] = metadata
//
//        return BundleDetail(metadata: metadata, revisions: [])
//    }
//
//    func bundle(_ bundleId: BundleMetadata.ID) -> BundleDetail? {
//        guard let metadata = self.bundleMap[bundleId] else {
//            return nil
//        }
//
//        return BundleDetail(
//            metadata: metadata,
//            revisions: revisions(forBundle: bundleId).map({ .init(tag: $0.tag, source: $0.source) })
//        )
//    }
//
//    func removeBundle(_ bundleId: BundleMetadata.ID) {
//        _ = bundleMap.removeValue(forKey: bundleId)
//        _ = bundleRevisions.removeValue(forKey: bundleId)
//    }
//
//
//    // MARK: Revisions
//    func revisions(
//        forBundle bundleId: BundleMetadata.ID
//    ) -> [BundleRevision] {
//        return bundleRevisions[bundleId]?.values.sorted(by: { $0.tag < $1.tag }) ?? []
//    }
//
//    func addRevision(
//        _ tag: BundleRevision.Tag,
//        source: URL,
//        toBundle bundleId: BundleMetadata.ID
//    ) -> BundleRevision {
//        let revision = BundleRevision(
//            bundleId: bundleId,
//            tag: tag,
//            source: source
//        )
//
//        bundleRevisions[bundleId]![revision.id] = revision
//        return revision
//    }
//
//    func revision(
//        _ tag: BundleRevision.Tag,
//        forBundle bundleId: BundleMetadata.ID
//    ) -> BundleRevision? {
//        bundleRevisions[bundleId]?[tag]
//    }
//
//    func removeRevision(_ tag: BundleRevision.Tag, forBundle bundleId: BundleMetadata.ID) async throws {
//        _ = bundleRevisions[bundleId]?.removeValue(forKey: tag)
//    }
// }
