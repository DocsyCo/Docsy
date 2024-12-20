//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import Foundation
import AsyncHTTPClient
import NIOHTTP1
import DocumentationKit


/// A type that can execute documentation server http requests
public protocol HTTPClientProtocol: Sendable {
    typealias Request = HTTPClientRequest
    typealias Response = HTTPClientResponse
    
    var baseURI: URL { get }
    
    /// Execute HTTP requests against a documentation server
    ///
    /// - Parameters:
    ///   - request: the http request
    func execute(request: HTTPClientRequest) async throws -> HTTPClientResponse
}

extension HTTPClientProtocol {
    /// Execute requests against a http server and decode the response
    ///
    /// - Parameters:
    ///   - method: the http method to use.
    ///   - path: the endpoint path.
    ///   - body: the request body.
    ///   - responseType: the type of the resonse.
    /// - Returns: The decoded response response
    func request<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        body: HTTPClientRequest.Body? = nil,
        as responseType: Response.Type = Response.self
    ) async throws -> Response {
        let responseBody: HTTPClientResponse.Body = try await self.request(
            method: method,
            path: path,
            body: body
        )
        
        return try await responseBody.collectJSON(as: Response.self, upTo: 1024*1024*512)
    }
    
    /// Execute requests against a http server and decode the response
    ///
    /// - Parameters:
    ///   - method: the http method to use.
    ///   - path: the endpoint path.
    ///   - body: the request body.
    ///   - responseType: the type of the resonse.
    /// - Returns: The decoded response response
    func request(
        method: HTTPMethod,
        path: String,
        body: HTTPClientRequest.Body? = nil
    ) async throws {
        let _: HTTPClientResponse.Body = try await self.request(
            method: method,
            path: path,
            body: body
        )
    }
    
    func request<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        body: some Encodable,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        try await request(
            method: method,
            path: path,
            body: .json(body),
            as: Response.self
        )
    }
}


// MARK: Client
public struct HTTPClient: HTTPClientProtocol {
    public let baseURI: URL
    let client: AsyncHTTPClient.HTTPClient
    
    public init(baseURI: URL, client: AsyncHTTPClient.HTTPClient = .shared) {
        self.baseURI = baseURI
        self.client = client
    }
    
    public func execute(request: HTTPClientRequest) async throws -> HTTPClientResponse {
        try await client.execute(request, timeout: .seconds(10))
    }
}


// MARK: Utility
fileprivate extension HTTPClientProtocol {
    func request(
        method: HTTPMethod,
        path: String,
        body: HTTPClientRequest.Body? = nil
    ) async throws -> HTTPClientResponse.Body {
        let url = baseURI.appending(path: path).absoluteString
        var request = HTTPClientRequest(url: url)
        
        request.method = method
        
        if let body {
            request.body = body
        }
        
        let response = try await execute(request: request)
        
        try await response.raiseStatus()
        
        return response.body
    }
}


fileprivate extension HTTPClientRequest.Body {
    static func json<E: Encodable>(_ value: E, encoder: JSONEncoder = .init()) throws -> Self {
        try .bytes(encoder.encode(value))
    }
}

extension HTTPClientResponse.Body {
    func collectJSON<T: Decodable>(
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder(),
        upTo maxBytes: Int
    ) async throws -> T {
        var responseData = try await collect(upTo: maxBytes)
    
        guard
            let responseJSON = try responseData.readJSONDecodable(
                T.self,
                decoder: decoder,
                length: responseData.readableBytes
            )
        else {
            throw NSError(
                domain: "ByteBufferError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read json data from ByteBuffer"]
            )
        }
        
        return responseJSON
    }
}


fileprivate extension HTTPClientResponse {
    func raiseStatus() async throws(ErrorResponse) {
        if 200..<300 ~= status.code {
            return
        }

        switch status.code {
        case 400..<500:
            do {
                var body = try await body.collect(upTo: 1024*1024*100)
                
                guard body.readableBytes > 0 else {
                    throw ErrorResponse(status: Int(status.code), detail: nil)
                }
                
                do {
                    throw try body.readJSONDecodable(
                        ErrorResponse.self,
                        length: body.readableBytes
                    )!
                } catch {
                    throw ErrorResponse(
                        status: Int(status.code),
                        detail: .init(
                            "failed to decode error: \(error)"
                        )
                    )
                }
            } catch {
                throw ErrorResponse(
                    status: Int(status.code),
                    detail: .init("failed to load body")
                )
            }
        default:
            throw ErrorResponse(status: Int(status.code), detail: nil)
        }
    }
}
