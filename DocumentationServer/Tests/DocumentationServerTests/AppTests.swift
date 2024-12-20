import HummingbirdTesting
import Logging
//import PostgresKit
import Testing
import Foundation

import DocumentationKit
@testable import DocumentationServer
@testable import DocumentationServerClient



extension DocumentationServer.Configuration {
    static var test: Self { Self(hostname: "localhost", port: 8080, logLevel: .trace) }
}

@Suite
struct AppTests {
    @Test
    func status() async throws {
        let server = DocumentationServer(configuration: .test)
        let app = try await server.application()
        
        try await app.test(.router) { client in
            try await client.execute(uri: "/status", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }
}
