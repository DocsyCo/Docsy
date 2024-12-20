//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 07.12.24.
//

import Foundation
import HummingbirdTesting
@testable import DocumentationServerClient


fileprivate struct TestClient: HTTPClientProtocol {
    let baseURI: URL = URL(string: "http://localhost")!
    let client: any TestClientProtocol
    
    init(_ client: any TestClientProtocol) {
        self.client = client
    }
    
    func execute(request: Request) async throws -> Response {
        let bodyBuffer = try await request.body?.collect(upTo: Int.max)
        
        print(request)
        let response = try await client.executeRequest(
            uri: String(request.url.trimmingPrefix(baseURI.absoluteString)),
            method: try .init(request.method),
            headers: .init(request.headers, splitCookie: false),
            body: bodyBuffer
        )
        var body = response.body
        print(body.readString(length: response.body.readableBytes) ?? "-")
        
        return .init(
            version: .http1_0,
            status: .init(statusCode: response.status.code),
            headers: .init(response.headers),
            body: .bytes(response.body)
        )
    }
}

extension HTTPDocumentationRepository {
    init(client: any TestClientProtocol) {
        self.init(client: TestClient(client))
    }
}
