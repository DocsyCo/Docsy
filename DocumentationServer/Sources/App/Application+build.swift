import Hummingbird
import Logging
import PostgresKit

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var inMemory: Bool { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

public enum DocumentationServiceFeature {
    case endpoint
}

public protocol DocumentationService {
    typealias Endpoint = RouteCollection<BasicRequestContext>
    
    static var id: DocumentationServiceID { get }
    
    func endpoint() -> Endpoint
}

public struct DocumentationServiceID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let repository = DocumentationServiceID(rawValue: "repository")
    public static let storage = DocumentationServiceID(rawValue: "storage")
}




extension PostgresClient.Configuration {
    init(from environment: Environment) throws {
        let host = environment.get("POSTGRES_HOST") ?? "localhost"
        let port = environment.get("POSTGRES_PORT", as: Int.self) ?? 5432
        let user = try environment.require("POSTGRES_USER")
        let password = try environment.require("POSTGRES_PASSWORD")
        let database = try environment.require("POSTGRES_DB")
        
        self.init(
            host: host,
            port: port,
            username: user,
            password: password,
            database: database,
            tls: .prefer(.clientDefault)
        )
    }
}
// Request context used by application
typealias AppRequestContext = BasicRequestContext



///  Build application
///// - Parameter arguments: application arguments
//public func buildApplication(
//    _ arguments: some AppArguments,
//    environment: Environment = .init()
//) async throws -> some ApplicationProtocol {
//    let logger = {
//        var logger = Logger(label: "DoccServeAPI")
//        logger.logLevel = arguments.logLevel ?? .info
//        return logger
//    }()
//    
//    
//    let repositories = Repositories(
//        documentation: InMemoryDocumentationRepository()
//    )
//    
////    let router = buildRoRepositoryServiceuter(repositories: repositories)
//    
////    let postgresClient: PostgresClient? = if !arguments.inMemory {
////        PostgresClient(
////            configuration: try .init,
////            backgroundLogger: logger
////        )
////    } else { nil }
//    
//    let storage = try await S3Storage().create()
//
//    var app = Application(
//        router: router,
//        configuration: .init(
//            address: .hostname(arguments.hostname, port: arguments.port),
//            serverName: "DoccServeAPI"
//        ),
//        logger: logger
//    )
//    
////    if let postgresClient {
////        app.addServices(postgresClient)
////    }
//    
//    return app
//}

enum RequirementError: Error {
    case missing(_ key: String)
}

extension Environment {
    func require(_ key: String) throws (RequirementError) -> String {
        guard let value = get(key) else {
            throw RequirementError.missing(key)
        }
        return value
    }
    
    func require<T: LosslessStringConvertible>(_ key: String, as type: T.Type) throws (RequirementError) -> T {
        guard let value = get(key, as: T.self) else {
            throw RequirementError.missing(key)
        }
        
        return value
    }
}

import DocumentationKit
import Foundation

//struct User: Identifiable, Codable {
//    let id: UUID
//    let displayName: String
//}
//
//struct UserGroup: Identifiable, Codable {
//    let id: UUID
//    let ownerId: User.ID
//    let displayName: String
//}
//
//struct UserGroupMember: Codable {
//    let userId: User.ID
//    let groupId: UserGroup.ID
//}
//
//
//struct Permission: LosslessStringConvertible, Codable {
//    enum Scope: String {
//        case user
//        case group
//        case repository
//    }
//    
//    let scope: Scope
//    let id: UUID
//    
//    init(scope: Scope, id: UUID) {
//        self.scope = scope
//        self.id = id
//    }
//    
//    init?(_ description: consuming String) {
//        var value = description.lowercased()
//        let rawScope = value.prefix(while: { $0 != ":" })
//        
//        guard let scope = Scope(rawValue: String(rawScope)) else {
//            return nil
//        }
//        
//        value.removeFirst(rawScope.count)
//        
//        guard let id = UUID(uuidString: value) else {
//            return nil
//        }
//        
//        self.init(scope: scope, id: id)
//    }
//    
//    var description: String { scope.rawValue + ":" + id.uuidString }
//    
//    func encode(to encoder: any Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(description)
//    }
//    
//    init(from decoder: any Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let description = try container.decode(String.self)
//        guard let value = Self(description) else {
//            throw DecodingError.dataCorrupted(.init(
//                codingPath: container.codingPath,
//                debugDescription: "Could not parse permission from '\(description)'"
//            ))
//        }
//        
//        self = value
//    }
//}
//
////struct UserTokenService {}
//
//struct UserDetail: Codable {
//    let id: UUID
//    let displayName: String
//    
//    let groups: [UserGroup.ID]
//    let groups: User
//}
//
//protocol UserRepository {
//    func createUser(displayName: String) async throws -> UserDetail
//    func user(_ id: User.ID) async throws -> UserDetail?
//    func deleteUser(_ id: User.ID) async throws
//    
//    func createGroup(displayName: String, ownerId: User.ID) async throws -> UserGroup
//    func group(id: UserGroup.ID) async throws -> UserGroup
//    func deleteGroup(id: UserGroup.ID) async throws
//    
//    func addUser(_ userId: User.ID, toGroup groupId: UserGroup.ID) async throws -> UserGroupMember
//}

//struct AuthController {
//    func
//}
//
//struct StorageProviderRepository {
//    init(providers: [String: ])
//    func sign(url: URL) async throws -> URL
//}
//
//struct NoAuthStorageProvider {
//    
//}
//

struct Repositories {
    let documentation: DocumentationRepository
    init(documentation: DocumentationRepository) {
        self.documentation = documentation
    }
}

///// Build router
//func buildRouter(repositories: Repositories) -> Router<AppRequestContext> {
//    let router = Router(context: AppRequestContext.self)
//    
//    // Add middleware
//    router.addMiddleware {
//        // logging middleware
//        LogRequestsMiddleware(.debug)
//    }
//    
//    // Add health endpoint
//    router.get("/health") { _, _ -> HTTPResponse.Status in
//        return .ok
//    }
//    
//    let api = router.group("api")
//        
//    
//    // Bundles
//    let bundleRepository = InMemoryDocumentationRepository()
//    let bundles = BundleController(repository: bundleRepository)
//    api.addRoutes(bundles.endpoints, atPath: "/bundles")
//    
//    // Files
//    // let search = SearchController(repository: repositories.search)
//    // api.addRoutes(search.endpoints, atPath: "/search")
//
//    // Search
//    // let search = SearchController(repository: repositories.search)
//    // api.addRoutes(search.endpoints, atPath: "/search")
//    
//    return router
//}
