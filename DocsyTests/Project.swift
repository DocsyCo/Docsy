//
//  DocsyTests.swift
//  DocsyTests
//
//  Created by Noah Kamara on 19.11.24.
//
import Foundation
import Testing
@testable import Docsy

class MockProject: Project {
    private let _isPersistent: Bool
    override var isPersistent: Bool { _isPersistent }
    var onPersist: (() -> Void)? = nil
    
    
    init(
        isPersistent: Bool = false,
        identifier: String = UUID().uuidString,
        displayName: String = UUID().uuidString,
        items: [Project.Node] = [],
        references: [BundleIdentifier : Project.Bundle] = [:]
    ) {
        self._isPersistent = isPersistent
        super.init(displayName: displayName, items: items, references: references)
    }
    
    override func persist() async throws {
        onPersist?()
    }
}

extension Workspace.Configuration {
    static let test = Self(inMemory: true)
}


@Suite("Projects")
struct ProjectTest {
    @Test
    func initWorkspace() async throws {
        let project = MockProject(isPersistent: true)
        let workspace = try Workspace(project: project, config: .test)

        // initial project was set
        #expect(workspace.projectIdentifier == project.identifier)
        #expect(workspace.projectDisplayName == project.displayName)
        
        // projects should be persisted before being unloaded
        try await confirmation { confirm in
            project.onPersist = { confirm() }
            try await workspace.save()
        }
    }
    
    @Test
    func loadProject() async throws {
        let startProject = MockProject(isPersistent: true)
        let workspace = try Workspace(project: startProject, config: .test)
        
        let newProject = MockProject(isPersistent: true)
        
        // projects should be persisted before being unloaded
        try await confirmation { confirm in
            startProject.onPersist = { confirm() }
            try await workspace.load(newProject)
        }

        // new project was set
        #expect(workspace.projectIdentifier == newProject.identifier)
        #expect(workspace.projectDisplayName == newProject.displayName)
        
        // loaded project can be saved
        try await confirmation { confirm in
            newProject.onPersist = { confirm() }
            try await workspace.save()
        }
    }
}
