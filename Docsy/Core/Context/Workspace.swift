//
//  Workspace.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation
import DocumentationKit


import DocumentationKit



public class Workspace {
    // MARK: Sub Models
    let bundleRepository: BundleRepository = .init()
    let metadata: WorkspaceMetadata = .init()
    let navigator: Navigator = .init()
    
    // MARK: Options
    private let config: Configuration
    private let fileManager: FileManager
    
    // MARK: Project
    private var project: Project
    private(set) var search: SearchIndex
    
    init(
        config: Configuration = .init(),
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.config = config
        self.project = .scratchpad()
        
        let search = try loadSearchIndex(
            config: config,
            projectId: project.identifier,
            fileManager: fileManager
        )
        self.search = search
    }
}

// MARK: Project Management
extension Workspace {
    private var plugins: [DocumentationContextPlugin] {
        [metadata, navigator]
    }
    
    func save() async throws {
        guard project.isPersistent else { return }
        
        for plugin in plugins {
            try await plugin.willSave(project)
        }
        
        try project.validate()
        
        try await project.persist()
    }
    
    
    func open(_ newProject: Project, saveCurrent: Bool = true) async throws {
        try newProject.validate()
        
        if saveCurrent {
            try await save()
        }
        
        // Register Bundles
        await bundleRepository.unregisterAll()
        
        for reference in newProject.references.values {
            let dataProvider = ProjectSourceDataProvider(reference.source)
            let bundle = reference.bundle()
            await bundleRepository.registerBundle(bundle, withProvider: dataProvider)
        }
        

        self.project = newProject
        
        // Plugins
        for plugin in plugins {
            try await plugin.load(newProject, in: self)
        }

        
        // Load Search Index
        let search = try loadSearchIndex(
            config: config,
            projectId: newProject.identifier,
            fileManager: fileManager
        )
        
        self.search = search
    }

    func addBundle(
        _ bundle: DocumentationBundle,
        with provider: BundleRepositoryProvider
    ) async throws {
        await self.bundleRepository.registerBundle(bundle, withProvider: provider)
        try await navigator.didAddBundle(with: bundle.identifier, in: self)
    }
}


fileprivate func loadSearchIndex(
    config: Workspace.Configuration,
    projectId: String,
    fileManager: FileManager
) throws -> SearchIndex {
    guard !config.inMemory else {
        return try SearchIndex()
    }
    
    let searchIndexUrl = URL
        .cachesDirectory
        .appending(components: projectId, "search")
    
    if !fileManager.fileExists(atPath: searchIndexUrl.path()) {
        try fileManager.createDirectory(at: searchIndexUrl, withIntermediateDirectories: true)
    }
    
    return try SearchIndex.openSearchIndex(at: searchIndexUrl, createIfNeeded: true)
}

// MARK: Configuration
extension Workspace {
    struct Configuration {
        var inMemory: Bool = false
    }
}

// MARK: DocumentationContext
extension Workspace: DocumentationContext {
    func bundle(with identifier: BundleIdentifier) async -> DocumentationBundle? {
        await bundleRepository.bundle(with: identifier)
    }

    func contentsOfUrl(_ url: URL) async throws -> Data {
        try await bundleRepository.contentsOfUrl(url)
    }
}

