//
//  Navigator.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

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


//struct FileSystemCache {
//    let rootURL: URL
//    
//    
//    init(
//        rootURL: URL
//    ) {
//        self.rootURL = rootURL
//    }
//    
//    func clear() {
//        
//    }
//}

extension Navigator: WorkspaceComponent {
    func willSave(_ project: Project) async throws {
        let nodes = await self.nodes
        let topLevelIdToBundleId = self.topLevelIdToBundleId
        
        let projectItems: [Project.Node] = nodes.map { node in
            switch node.kind {
            case .bundle:
                precondition(node.id != nil, "bundle node must always have an identifier")
                return .bundle(node.displayName, node.id!.bundle)
            case .groupMarker:
                return .groupMarker(node.displayName)
            }
        }
        
        project.items = projectItems
    }

    func load(project: Project) async throws {
        await MainActor.run {
            self.indices.removeAll()
            self.nodes.removeAll()
        }
        
        var topLevelIdToBundleId: [UInt32: BundleIdentifier] = [:]
        var newNodes: [TopLevelNode] = []
        
        for item in project.items {
            let node: TopLevelNode
            
            switch item {
            case .bundle(let identifier, let displayName):
                /// Generate TopLevel ID and register in navigator
                let id = await idGenerator.next()
                
                topLevelIdToBundleId[id] = identifier
                node = .bundle(id: id, bundleIdentifier: identifier, displayName: displayName)
                newNodes.append(node)
                
            case .groupMarker(let displayName):
                node = .groupMarker(displayName: displayName)
            }
            
            newNodes.append(node)
        }
        
        Task { @MainActor in
            self.indices = [:]
            self.nodes = newNodes
            self.topLevelIdToBundleId = topLevelIdToBundleId
        }
    }
}

@Observable
public class Navigator {
    private var idGenerator: IDGenerator
    
    private(set) var indices: [BundleIdentifier: NavigatorIndex] = [:]
    private var topLevelIdToBundleId: [UInt32: BundleIdentifier] = [:]
    
    @MainActor
    private(set) var nodes: [TopLevelNode] = []
    
    var selection: NavigatorID? = nil
    
    init(idGenerator: IDGenerator = IDGenerator()) {
        self.idGenerator = idGenerator
    }
    
    struct NavigatorID: RawRepresentable, Hashable {
        let rawValue: UInt64
        
        public var topLevelId: UInt32 { UInt32(rawValue & 0xFFFFFFFF) }
        public var nodeId: UInt32 { UInt32(rawValue >> 32) }
    }
    
//    func insertIndex(_ index: NavigatorIndex) {
//        defer { topLevelIdCounter += 1 }
//        
//        let topLevelId = topLevelIdCounter
//        bundleToIndexId[index.bundleIdentifier] = bundleIndex
//        children.first(where: { $0.id == topLevelId })
//    }
//    
//    func removeIndex(for identifier: BundleIdentifier) {
//        guard let indexId = bundleToIndexId[identifier] else {
//            return
//        }
//        
//        guard let index = indices.removeValue(forKey: indexId) else {
//            return
//        }
//        
//        _ = bundleToIndexId.removeValue(forKey: index.bundleIdentifier)
//    }
//    
//    func serialize() -> [Project.Node] {
//        
//    }
    
    /// If available, returns the path from the numeric compound ID inside the navigator tree.
//    @MainActor
//    func path(for id: NavigatorID) -> String? {
//        guard let bundleIdentifier = topLevelIdToBundleId[id.topLevelId] else {
//            return
//        }
//
//        guard let navigator = indices[id.topLevelId] else {
//            print("navigator not found")
//            return nil
//        }
//        
//        return navigator.path(for: id.nodeId)
//    }    
}




extension Navigator {
    final class TopLevelNode: Identifiable {
        typealias Identifier = (topLevel: UInt32, bundle: BundleIdentifier)
        
        enum Kind: Codable {
            case bundle
            case groupMarker
        }

        let id: Identifier?
        
        let kind: Kind
        var displayName: String
        
        private init(
            id: Identifier?,
            kind: Kind,
            displayName: String
        ) {
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
            bundleIdentifier: String,
            displayName: String
        ) -> TopLevelNode {
            TopLevelNode(
                id: Identifier(id, bundleIdentifier),
                kind: .bundle,
                displayName: displayName
            )
        }
    }
}
