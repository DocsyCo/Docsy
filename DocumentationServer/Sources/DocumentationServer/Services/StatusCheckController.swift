//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import Foundation
import Hummingbird

struct StatusCheckController {
    let services: Set<DocumentationServiceID>
    
    init(services: Set<DocumentationServiceID>) {
        self.services = services
    }
    
    var endpoints: RouteCollection<BasicRequestContext> {
        RouteCollection()
            .get("/", use: index)
    }
    
    @Sendable
    func index(_ request: Request, context: BasicRequestContext) async throws -> ServerStatus {
        return ServerStatus(
            services: services
        )
    }
}


struct ServerStatus: Codable, ResponseEncodable {
    let services: Set<DocumentationServiceID>
    // let auth: AuthenticationService?
}

