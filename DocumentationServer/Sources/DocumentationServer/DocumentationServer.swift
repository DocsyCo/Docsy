//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 08.12.24.
//

import Foundation
import Hummingbird
import Logging


/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public extension DocumentationServer {
    struct Configuration {
        public let hostname: String
        public let port: Int
        public let logLevel: Logger.Level
        
        public init(
            hostname: String,
            port: Int,
            logLevel: Logger.Level = .info
        ) {
            self.hostname = hostname
            self.port = port
            self.logLevel = logLevel
        }
    }
}

public actor DocumentationServer {
    // Request Context used by the server
    typealias RequestContext = BasicRequestContext
    
    private(set) var services: [DocumentationServiceID: DocumentationService] = [:]
    public let configuration: Configuration
    
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    public func registerService<Service: DocumentationService>(_ service: Service) {
        services[Service.id] = service
    }
    
    public func run() async throws {
        let app = try application()
        try await app.runService()
    }
    
    public func application() throws -> some ApplicationProtocol {
        let logger = {
            var logger = Logger(label: "DocumentationServer")
            logger.logLevel = configuration.logLevel
            return logger
        }()
        
        let router = buildRouter()
        
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(configuration.hostname, port: configuration.port),
                serverName: "DocumentationServer"
            ),
            logger: logger
        )
        
        return app
    }
    
    func buildRouter() -> Router<RequestContext> {
        let router = Router(context: RequestContext.self)
        
        // Add middleware
        router.addMiddleware {
            // logging middleware
            LogRequestsMiddleware(.debug)
        }
        
                
        let api = router.group("/api")
        
        for (key, service) in services {
            api.addRoutes(service.endpoints(), atPath: "/\(key.rawValue)")
        }
                
        // Files
        // let search = SearchController(repository: repositories.search)
        // api.addRoutes(search.endpoints, atPath: "/search")

        // Search
        // let search = SearchController(repository: repositories.search)
        // api.addRoutes(search.endpoints, atPath: "/search")
        
        // Add status endpoint
        let statusCheck = StatusCheckController(services: Set(services.keys))
        router.addRoutes(statusCheck.endpoints, atPath: "/status")
        
        return router
    }
}
