//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 07.12.24.
//

import Foundation
import HummingbirdTesting
import PostgresKit
@testable import App

extension ByteBuffer {
    static func encoding(
        _ encodable: some Encodable,
        encoder: JSONEncoder = .init()
    ) throws -> Self {
        let data = try encoder.encode(encodable)
        return ByteBuffer(data: data)
    }
}


extension TestResponse {
    func raiseStatus() throws(ErrorResponse) {
        if 200..<300 ~= status.code {
            return
        }

        switch status.code {
        case 400..<500:
            var body = body
            let string = body.readString(length: body.readableBytes)
            throw ErrorResponse(status: status, detail: string)
        default:
            throw ErrorResponse(status: status, detail: nil)
        }
    }
    
    func json<T: Decodable>(_ type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        try raiseStatus()
        
        var body = self.body
        
        let length = body.readableBytes
        
        // Read bytes from the body
        guard let jsonData = body.readData(length: length) else {
            throw NSError(domain: "ByteBufferError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to read data from ByteBuffer"])
        }
        return try decoder.decode(T.self, from: jsonData)
    }

}


struct AnyError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}
