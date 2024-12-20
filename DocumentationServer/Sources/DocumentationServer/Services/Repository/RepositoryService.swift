//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 08.12.24.
//

import Foundation
import Hummingbird
import DocumentationKit

public struct RepositoryService<Repository: DocumentationRepository>: DocumentationService {
    public static var id: DocumentationServiceID { .repository }

    let repository: Repository
    
    public init(repository: Repository) {
        self.repository = repository
    }
    
    public func endpoints() -> Endpoints {
        let controller = BundleController(repository: repository)
        return controller.endpoints
    }    
}
