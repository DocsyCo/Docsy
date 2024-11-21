//
//  WorkspaceMetadata.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation

@Observable
final class WorkspaceMetadata: Sendable {
    @MainActor
    private(set) var identifier: String = ""
    
    @MainActor
    var displayName: String = "No Project"
    
    init() {}
    
    @MainActor
    func setDisplayName(_ displayName: String) {
        self.displayName = displayName
    }
}

extension WorkspaceMetadata: DocumentationContextPlugin {
    @MainActor
    func load(_ project: Project, in _: any DocumentationContext) async throws {
        withMutation(keyPath: \.identifier) {
            withMutation(keyPath: \.displayName) {
                self.identifier = project.identifier
                self.displayName = project.displayName
            }
        }
    }

    func willSave(_ project: Project) async throws {
        let identifier = await identifier
        async let displayName = displayName
        
        precondition(project.identifier == identifier, "should not call willSave before load")
        project.displayName = await displayName
    }
}
