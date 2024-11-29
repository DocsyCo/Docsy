//
//  File.swift
//  DocumentationKit
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation

package protocol WorkspaceContext {
    func contentsOfUrl(url: URL) async throws -> Data
}


///// <#Description#>
//package protocol WorkspaceComponent {
//    /// called when a component should load a new project.
//    /// > the component is responsible for resetting it's state
//    ///
//    /// - Parameters:
//    ///   - project: the project that the component should load
//    ///   - workspace: the
//    func load(project: Project, in context: some WorkspaceContext) async throws
//    
//    /// Called before a Workspace saves a project.
//    ///
//    /// > Use this function to persist any component-internal changes to the project
//    /// - Parameter project: the project that will be saved
//    func willSave(_ project: Project) async throws
//}
