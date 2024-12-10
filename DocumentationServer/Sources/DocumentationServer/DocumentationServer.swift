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
        let app = application()
        try await app.runService()
    }
    
    public func application() -> some ApplicationProtocol {
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
        
        // Add health endpoint
        router.get("/health") { _, _ -> HTTPResponse.Status in
            return .ok
        }
                
        for (key, service) in services {
            service.endpoints()
            router.addRoutes(service.endpoint(), atPath: .init(key.rawValue))
        }
        // Bundles
//        let bundleRepository = InMemoryDocumentationRepository()
//        let bundles = BundleController(repository: bundleRepository)
//        api.addRoutes(bundles.endpoints, atPath: "/bundles")
        
        // Files
        // let search = SearchController(repository: repositories.search)
        // api.addRoutes(search.endpoints, atPath: "/search")

        // Search
        // let search = SearchController(repository: repositories.search)
        // api.addRoutes(search.endpoints, atPath: "/search")
        
        return router
    }
}
