//
//  WorkspaceMetadata.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation

@Observable
final class WorkspaceMetadata {
    private(set) var identifier: String = ""
    var displayName: String = "No Project"
    
    init() {}
}

extension WorkspaceMetadata: DocumentationContextPlugin {
    func load(_ project: Project, in _: any DocumentationContext) async throws {
        withMutation(keyPath: \.identifier) {
            withMutation(keyPath: \.displayName) {
                self.identifier = identifier
                self.displayName = displayName
            }
        }
    }

    func willSave(_ project: Project) async throws {
        precondition(project.identifier == identifier, "should not call willSave before load")
        project.displayName = displayName
    }
}
