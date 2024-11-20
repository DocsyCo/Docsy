//
//  Workspace.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation


@Observable
public class Workspace {
    let config: Configuration
    
    private let fileManager: FileManager
    private(set) var search: SearchIndex
    private let navigator: Navigator
    
    private var project: Project
    
    var canPersist: Bool {
        access(keyPath: \.project)
        return project.isPersistent
    }
    
    var projectIdentifier: String { project.identifier }
    var displayName: String { project.displayName }
    
    func setDisplayName(_ newValue: String) {
        withMutation(keyPath: \.displayName) {
            project.displayName = newValue
        }
    }
    
    init(
        project: Project,
        config: Configuration = .init(),
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.config = config
        self.project = project
        self.navigator = Navigator()
        
        let search = try loadSearchIndex(
            config: config,
            projectId: project.identifier,
            fileManager: fileManager
        )
        self.search = search
    }
    
    func save() async throws {
        try await navigator.willSave(project)
        
        guard canPersist else { return }
        
        try await project.persist()
    }
    
    func load(_ newProject: Project) async throws {
        try await save()
        
        let search = try loadSearchIndex(
            config: config,
            projectId: newProject.identifier,
            fileManager: fileManager
        )
        self.search = search
        
        withMutation(keyPath: \.project) {
            self.project = newProject
        }
        
        try await self.navigator.load(project: project)
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

extension Workspace {
    struct Configuration {
        var inMemory: Bool = false
    }
}
