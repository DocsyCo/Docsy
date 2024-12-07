//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 07.12.24.
//

import Foundation
import Hummingbird

public protocol DescribedError: Error, LocalizedError, CustomStringConvertible {
    var errorDescription: String { get }
}

extension DescribedError {
    public var localizedDescription: String { errorDescription }
    public var description: String { errorDescription }
}

struct ErrorResponse: DescribedError, Encodable, ResponseEncodable {
    var errorDescription: String {
        if let detail {
            "Error(\(status)): \(detail.value)"
        } else {
            "Error(\(status)): No Detail"
        }
    }
    
    struct Detail: Sendable, Encodable {
        let value: any (Encodable & Sendable)
        
        init <T: Encodable & Sendable>(_ value: T) {
            self.value = value
        }
        
        func encode(to encoder: any Encoder) throws {
            try value.encode(to: encoder)
        }
    }
    
    let status: HTTPResponse.Status
    let detail: Detail?
    
    init(status: HTTPResponse.Status, detail: Detail?) {
        self.status = status
        self.detail = detail
    }
    
    @_disfavoredOverload
    init<D: Encodable & Sendable>(status: HTTPResponse.Status, detail: D?) {
        if let detail {
            self.init(status: status, detail: .init(detail))
        } else {
            self.init(status: status, detail: nil)
        }
    }
    
    enum CodingKeys: CodingKey {
        case status
        case detail
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.status.code, forKey: .status)
        try container.encode(self.detail, forKey: .detail)
    }
    
    func response(from request: Request, context: some RequestContext) throws -> Response {
        var response = try context.responseEncoder.encode(self, from: request, context: context)
        response.status = status
        return response
    }
}
