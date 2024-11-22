//
//  Navigator.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation
import SwiftDocC
import DocumentationKit

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
            print("navigator not found")
            return nil
        }

        guard let navigator = indices[id.topLevelId] else {
            print("navigator not found")
            return nil
        }
        
        return navigator.path(for: id.nodeId)
    }
    
    /// If available, returns the path from the numeric compound ID inside the navigator tree.
    @MainActor
    func topicUrl(for id: NavigatorID) -> DocumentationURI? {
        guard let navigator = indices[id.topLevelId] else {
            print("navigator not found")
            return nil
        }
        
        let path = navigator.path(for: id.nodeId)
                
        let topicUrl = path.flatMap({
            DocumentationURI(bundleIdentifier: navigator.bundleIdentifier, path: $0)
        })
        
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


// MARK: DocumentationContextPlugin
extension Navigator: DocumentationContextPlugin {
    func willSave(_ project: Project) async throws {
        let nodes = await self.nodes
        
        var projectItems: [Project.Node] = []
        
        for node in nodes {
            switch node.kind {
            case .bundle:
                precondition(node.id != nil, "bundle node must always have an identifier")
                let bundleIdentifier = await indices[node.id!]?.bundleIdentifier
                precondition(node.id != nil, "bundle node must have an index")
                
                projectItems.append(.bundle(.init(
                    displayName: node.displayName,
                    bundleIdentifier: bundleIdentifier!
                )))
            case .groupMarker:
                projectItems.append(.groupMarker(node.displayName))
            }
        }
        
        project.items = projectItems
    }

    
    /// called when a component should load a new project.
    /// > the component is responsible for resetting it's state
    func didAddBundle(with identifier: BundleIdentifier, in context: any DocumentationContext) async throws {
        guard let bundle = await context.bundle(with: identifier) else {
            print("NOT FOUND")
            return
        }
        
        let id = await idGenerator.next()
        let node = TopLevelNode.bundle(
            id: id,
            displayName: bundle.displayName
        )
        let index = try NavigatorIndex.readNavigatorIndex(
            url: bundle.indexURL,
            bundleIdentifier: bundle.identifier,
            readNavigatorTree: false,
            presentationIdentifier: nil,
            onNodeRead: { $0.topLevelId = id }
        )
        
        node.addTask { node in
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try index.readNavigatorTree(
                        timeout: 5.0,
                        queue: .global(qos: .userInitiated),
                        broadcast: { (_, isCompleted, error) in
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
        }
        
        await MainActor.run {
            self.indices[id] = index
            self.bundleIdToTopLevelId[identifier] = id
            withMutation(keyPath: \.nodes) {
                self.nodes.append(node)
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
        
        var idMap      = [String: UInt32]()
        var newNodes   = [TopLevelNode]()
        var newIndices = [UInt32: NavigatorIndex]()
        
        
        for item in project.items {
            switch item {
            case .bundle(let projectBundle):
                guard let bundle = await context.bundle(with: projectBundle.bundleIdentifier) else {
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
                newNodes.append(.bundle(
                    id: id,
                    displayName: bundle.displayName
                ))
                
            case .groupMarker(let displayName):
                newNodes.append(.groupMarker(displayName: displayName))
            }
        }
        
        
        for (id, index) in await indices {
            let node = newNodes.first(where: { $0.id == id })!
            
            node.addTask { node in
                try await withCheckedThrowingContinuation { continuation in
                    do {
                        try index.readNavigatorTree(
                            timeout: 5.0,
                            queue: .global(qos: .userInitiated),
                            broadcast: { (_, isCompleted, error) in
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
        guard let id = self.id(for: uri.path, with: .swift, bundleIdentifier: uri.bundleIdentifier) else {
            print("Not found in navigator \(uri)")
            return
        }
        
        if let selection, path(for: id) == path(for: selection) {
            return
        }
        
        guard id != self.selection else {
            return
        }
        
        self.selection = id
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
        let id: UInt32?
        
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
            
            self.loadingTask = Task {
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
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
        
        private init(
            id: UInt32?,
            kind: Kind,
            displayName: String
        ) {
            self.displayID = UUID()
            self.id = id
            self.kind = kind
            self.displayName = displayName
        }
        
        static func groupMarker(displayName: String) -> TopLevelNode {
            TopLevelNode(
                id: nil,
                kind: .groupMarker,
                displayName: displayName
            )
        }
        
        static func bundle(
            id: UInt32,
            displayName: String
        ) -> TopLevelNode {
            TopLevelNode(
                id: id,
                kind: .bundle,
                displayName: displayName
            )
        }
    }
}
