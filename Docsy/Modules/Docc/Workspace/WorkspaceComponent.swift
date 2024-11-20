//
//  DocsyWorkspaceComponent.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation


protocol WorkspaceProtocol {
    func bundle(for identifier: BundleIdentifier) async throws -> DocumentationBundle
    func contentsOfUrl(url: URL) async throws -> Data
}

protocol WorkspaceComponent {
    /// called when a component should load a new project.
    /// > the component is responsible for resetting it's state
    func load(project: Project) async throws
    
    /// Called before a Workspace saves a project.
    ///
    /// > Use this function to persist any component-internal changes to the project
    /// - Parameter project: the project that will be saved
    func willSave(_ project: Project) async throws
}

protocol DataProvider {
    func contentsOfUrl(_ url: URL) async throws
}
