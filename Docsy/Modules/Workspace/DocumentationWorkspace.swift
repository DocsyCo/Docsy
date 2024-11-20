//
//  DocumentationWorkspace.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation
import SwiftDocC

@Observable
public class DocumentationWorkspace {
    let config: Configuration
    
    private let fileManager: FileManager
    private(set) var search: SearchIndex
    private(set) var project: Project
    
    var canPersist: Bool {
        access(keyPath: \.project)
        return project.isPersistent
    }
    
    var projectIdentifier: String { project.identifier }
    var projectDisplayName: String { project.displayName }
    
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
    }
}

fileprivate func loadSearchIndex(
    config: DocumentationWorkspace.Configuration,
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

extension DocumentationWorkspace {
    struct Configuration {
        var inMemory: Bool = false
    }
}
