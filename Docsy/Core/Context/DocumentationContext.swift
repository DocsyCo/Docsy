//
//  DocsyWorkspaceComponent.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation
import DocumentationKit


protocol DocumentationContext {
    func bundle(with identifier: BundleIdentifier) async -> DocumentationBundle?
    func contentsOfUrl(_ url: URL) async throws -> Data
}

protocol DocumentationContextPlugin {
    var pluginId: String { get }
    
    /// called when a component should load a new project.
    /// > the component is responsible for resetting it's state
    func load(_ project: Project, in context: DocumentationContext) async throws

    func didAddBundle(with identifier: BundleIdentifier, in context: any DocumentationContext) async throws
    
    /// Called before a Workspace saves a project.
    ///
    /// > Use this function to persist any component-internal changes to the project
    /// - Parameter project: the project that will be saved
    func willSave(_ project: Project) async throws
}

extension DocumentationContextPlugin {
    var pluginId: String { "\(Self.self)" }
    
    func didAddBundle(with identifier: BundleIdentifier, in context: any DocumentationContext) async throws {}
}

extension BundleRepository: DocumentationContext {
    
}
