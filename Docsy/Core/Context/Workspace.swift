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
        project: Project,
        config: Configuration = .init(),
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.config = config
        self.project = project
        
        let search = try loadSearchIndex(
            config: config,
            projectId: project.identifier,
            fileManager: fileManager
        )
        self.search = search
    }
    
    func save() async throws {
        try await navigator.willSave(project)
        guard project.isPersistent else { return }
        try await project.persist()
    }
    
    func load(_ newProject: Project) async throws {
        try await save()
        
        // Register Bundles
        await bundleRepository.unregisterAll()
        
        for (bundleIdentifier, projectBundle) in project.references {
            let dataProvider = ProjectSourceDataProvider(projectBundle.source)
            let baseURL = URL(string: "http://localhost:8080/docsee/slothcreator")!
            
            let bundle = DocumentationBundle(
                info: .init(
                    displayName: projectBundle.displayName,
                    identifier: bundleIdentifier
                ),
                baseURL: baseURL,
                indexURL: baseURL.appending(component: "index"),
                themeSettingsUrl: nil
            )
            
            await bundleRepository.registerBundle(bundle, withProvider: dataProvider)
        }
        
        // Load Search Index
        let search = try loadSearchIndex(
            config: config,
            projectId: newProject.identifier,
            fileManager: fileManager
        )
        self.search = search
        self.project = newProject
        
        // Load Navigator
        try await self.metadata.load(project, in: self)
        try await self.navigator.load(project, in: self)
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
        await bundleRepository.bundle(for: identifier)
    }

    func contentsOfUrl(_ url: URL) async throws -> Data {
        try await bundleRepository.contentsOfUrl(url)
    }
}

