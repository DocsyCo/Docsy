//
//  Navigator.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import Foundation
import SwiftDocC

actor IDGenerator {
    private var nextID: UInt32

    init(startingFrom id: UInt32 = 0) {
        self.nextID = id
    }

    func next() -> UInt32 {
        defer { nextID += 1 }
        return nextID
    }
}

@Observable
public class Navigator {
    private var idGenerator: IDGenerator

    @MainActor
    private(set) var indices: [UInt32: NavigatorIndex] = [:]

    @MainActor
    private(set) var bundleIdToTopLevelId: [BundleIdentifier: UInt32] = [:]

    @MainActor
    private(set) var nodes: [TopLevelNode] = []

    @MainActor
    var selection: NavigatorID? = nil

    init(idGenerator: IDGenerator = IDGenerator()) {
        self.idGenerator = idGenerator
    }

    public struct NavigatorID: RawRepresentable, Hashable, CustomStringConvertible {
        public var description: String {
            "\(topLevelId).\(nodeId)"
        }

        public let rawValue: UInt64

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        public init(topLevelId: UInt32, nodeId: UInt32) {
            self.init(rawValue: UInt64(nodeId) << 32 | UInt64(topLevelId))
        }

        public var topLevelId: UInt32 { UInt32(rawValue & 0xFFFFFFFF) }
        public var nodeId: UInt32 { UInt32(rawValue >> 32) }
    }

    /// If available, returns the path from the numeric compound ID inside the navigator tree.
    @MainActor
    func path(for id: NavigatorID) -> String? {
        guard let index = indices[id.topLevelId] else {
            print("index not found")
            return nil
        }

        guard let navigator = indices[id.topLevelId] else {
            print("index not found")
            return nil
        }

        return navigator.path(for: id.nodeId)
    }

    /// If available, returns the path from the numeric compound ID inside the navigator tree.
    @MainActor
    func topicUrl(for id: NavigatorID) -> DocumentationURI? {
        guard let navigator = indices[id.topLevelId] else {
            print("index not found")
            return nil
        }

        let path = navigator.path(for: id.nodeId)

        let topicUrl = path.flatMap {
            DocumentationURI(bundleIdentifier: navigator.bundleIdentifier, path: $0)
        }

        return topicUrl
    }

    /// If available, returns the path from the numeric compound ID inside the navigator tree.
    @MainActor
    func id(
        for path: String,
        with language: InterfaceLanguage,
        bundleIdentifier: String
    ) -> NavigatorID? {
        guard let topLevelId = bundleIdToTopLevelId[bundleIdentifier] else {
            print("Unknown bundle", bundleIdentifier)
            return nil
        }

        guard let navigator = indices[topLevelId] else {
            print("navigator not found")
            return nil
        }

        guard let nodeId = navigator.id(for: path, with: language) else {
            print("did not find node for path", path)
            return nil
        }

        return .init(topLevelId: topLevelId, nodeId: nodeId)
    }
}

final class CachedResource: @unchecked Sendable {
    private let fileManager: FileManager
    let id: String
    let url: URL
    
    init(fileManager: FileManager = .default) throws {
        let id = "cached-"+UUID().uuidString
        let tempDir = fileManager.temporaryDirectory
        
        self.fileManager = fileManager
        self.id = id
        self.url = tempDir.appending(component: id, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
    }
    
    func put(_ data: Data, at path: String) throws {
        let fileURL = url.appending(path: path)
        try data.write(to: fileURL)
    }
    
    func getData(at path: String) throws -> Data {
        let fileURL = url.appending(path: path)
        return try fileManager.contents(of: fileURL)
    }
    
    deinit {
        try! fileManager.removeItem(at: url)
    }
}

// MARK: DocumentationContextPlugin

extension Navigator: DocumentationContextPlugin {
    func willSave(_ project: Project) async throws {
        let nodes = await nodes

        var projectItems: [Project.Node] = []

        for node in nodes {
            switch node.kind {
            case .bundle:
                precondition(node.reference != nil, "bundle node must always have a reference")
                let reference = node.reference!
                let topLevelId = await bundleIdToTopLevelId[reference.bundleIdentifier]!
                let index = await indices[topLevelId]!
                let nodeId = index.id(for: reference.path, with: .swift)!

                let displayName = index.navigatorTree.numericIdentifierToNode[nodeId]!.item.title
                projectItems.append(.init(displayName: displayName, reference: reference))

            case .groupMarker:
                projectItems.append(.init(displayName: node.displayName, reference: nil))
            }
        }

        project.items = projectItems
    }

    /// called when a component should load a new project.
    /// > the component is responsible for resetting it's state
    func didAddBundle(with identifier: BundleIdentifier, in context: any DocumentationContext) async throws {
        guard let bundle = await context.bundle(with: identifier) else {
            preconditionFailure("bundle must be added to context before calling didAddBundle")
        }

        let paths = ["availability.index", "data.mdb", "navigator.index"]
        
        let cachedIndex = try CachedResource()
        
        try await withThrowingTaskGroup(of: (String, Data).self) { group in
            for path in paths {
                group.addTask {
                    let data = try await context.contentsOfUrl(
                        DocumentationURI(
                            bundleIdentifier: bundle.identifier,
                            path: bundle.indexURL.appending(path: path).path()
                        )
                    )
                    
                    return (path, data)
                }
            }
            
            for try await (path, data) in group {
                try cachedIndex.put(data, at: path)
            }
        }
        
        let index = try NavigatorIndex.readNavigatorIndex(
            url: cachedIndex.url,
            bundleIdentifier: bundle.identifier,
            readNavigatorTree: true,
            presentationIdentifier: nil
        )

        let id = await idGenerator.next()
        let node = TopLevelNode.bundle(
            reference: .init(bundleIdentifier: identifier, path: ""),
            displayName: bundle.displayName
        )
        var newNodes = [TopLevelNode]()

        let tree = index.navigatorTree

        for topicId in tree.root.children.flatMap({ lang in lang.children.map { $0.id! } }) {
            let title = tree.numericIdentifierToNode[topicId]!.item.title
            let path = index.path(for: topicId)!

            newNodes.append(.bundle(
                reference: .init(bundleIdentifier: identifier, path: path),
                displayName: title
            ))
        }

        let _: Void = try await withCheckedThrowingContinuation { continuation in
            do {
                try index.readNavigatorTree(
                    timeout: 5.0,
                    queue: .global(qos: .userInitiated),
                    broadcast: { _, isCompleted, error in
                        if let error {
                            print("Error occured loading index", error)
                            continuation.resume(throwing: error)
                            return
                        }

                        if isCompleted {
                            Task { @MainActor in
                                node.isLoading = true
                            }
                            continuation.resume()
                        }
                    }
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
//        node.addTask { node in
//            try await withCheckedThrowingContinuation { continuation in
//                do {
//                    try index.readNavigatorTree(
//                        timeout: 5.0,
//                        queue: .global(qos: .userInitiated),
//                        broadcast: { _, isCompleted, error in
//                            if let error {
//                                print("Error occured loading index", error)
//                                continuation.resume(throwing: error)
//                                return
//                            }
//
//                            if isCompleted {
//                                Task { @MainActor in
//                                    node.isLoading = true
//                                }
//                                continuation.resume()
//                            }
//                        }
//                    )
//                } catch {
//                    continuation.resume(throwing: error)
//                }
//            }
//        }

        let prependNodes = newNodes
        await MainActor.run {
            self.indices[id] = index
            self.bundleIdToTopLevelId[identifier] = id
            withMutation(keyPath: \.nodes) {
                self.nodes.insert(contentsOf: prependNodes, at: 0)
            }
        }
    }

    func load(_ project: Project, in context: any DocumentationContext) async throws {
        await MainActor.run {
            self.indices.removeAll()
            self.nodes.removeAll()
            self.bundleIdToTopLevelId.removeAll()
            self.selection = nil
        }

        var idMap = [String: UInt32]()
        var newNodes = [TopLevelNode]()
        var newIndices = [UInt32: NavigatorIndex]()

        for item in project.items {
            guard let reference = item.reference else {
                newNodes.append(.groupMarker(displayName: item.displayName))
                continue
            }

            guard let bundle = await context.bundle(with: reference.bundleIdentifier) else {
                preconditionFailure("Project contained bundle that is not in repository")
            }

            // Generate TopLevel ID and register in navigator
            let id = await idGenerator.next()

            // create index
            let index = try NavigatorIndex.readNavigatorIndex(
                url: bundle.indexURL,
                bundleIdentifier: bundle.identifier,
                readNavigatorTree: false,
                presentationIdentifier: nil,
                onNodeRead: { $0.topLevelId = id }
            )
            newIndices[id] = index

            // create id
            idMap[bundle.identifier] = id
            newNodes.append(.bundle(reference: reference, displayName: item.displayName))
        }

        for (id, index) in await indices {
            let bundleId = index.bundleIdentifier
            let nodes = newNodes.filter { node in node.reference?.bundleIdentifier == bundleId }

            let task = Task {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    do {
                        try index.readNavigatorTree(
                            timeout: 5.0,
                            queue: .global(qos: .userInitiated),
                            broadcast: { _, isCompleted, error in
                                if let error {
                                    print("Error occured loading index", error)
                                    continuation.resume(throwing: error)
                                    return
                                }

                                if isCompleted {
                                    continuation.resume()
                                }
                            }
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            for node in nodes {
                node.addTask { _ in
                    try await task.value
                }
            }
        }

        let indices = newIndices
        let nodes = newNodes
        let bundleIdToTopLevelId = idMap

        await MainActor.run {
            self.indices = indices
            self.nodes = nodes
            self.bundleIdToTopLevelId = bundleIdToTopLevelId
        }
    }
}

extension Navigator {
    @MainActor
    func navigate(to uri: DocumentationURI) {
        guard let id = id(for: uri.path, with: .swift, bundleIdentifier: uri.bundleIdentifier) else {
            print("Not found in navigator \(uri)")
            return
        }

        if let selection, path(for: id) == path(for: selection) {
            return
        }

        guard id != selection else {
            return
        }

        selection = id
    }
}

// MARK: TopLevelNode

extension Navigator {
    @Observable
    final class TopLevelNode: Sendable, Identifiable {
        typealias Identifier = (topLevel: UInt32, bundle: BundleIdentifier)

        enum Kind: Codable {
            case bundle
            case groupMarker
        }

        let displayID: UUID
        let reference: DocumentationURI?

        let kind: Kind

        var displayName: String

        @MainActor
        var isLoading: Bool = false

        @MainActor
        var error: (any Error)? = nil

        var task: Task<Void, any Error>? = nil
        var loadingTask: Task<Void, any Error> = Task {}

        func addTask(_ task: @escaping (TopLevelNode) async throws -> Void) {
            let oldTask = self.task
            self.task = Task {
                try await oldTask?.value
                try await task(self)
            }

            loadingTask = Task {
                await MainActor.run {
                    self.isLoading = true
                    self.error = nil
                }

                do {
                    try await self.task?.value
                } catch {
                    print("Loading error", error)
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                    }
                    return
                }

                await MainActor.run {
                    self.isLoading = false
                }
            }
        }

        private init(
            kind: Kind,
            reference: DocumentationURI?,
            displayName: String
        ) {
            self.displayID = UUID()
            self.reference = reference
            self.kind = kind
            self.displayName = displayName
        }

        static func groupMarker(displayName: String) -> TopLevelNode {
            TopLevelNode(
                kind: .groupMarker,
                reference: nil,
                displayName: displayName
            )
        }

        static func bundle(
            reference: DocumentationURI,
            displayName: String
        ) -> TopLevelNode {
            TopLevelNode(
                kind: .bundle,
                reference: reference,
                displayName: displayName
            )
        }
    }
}
