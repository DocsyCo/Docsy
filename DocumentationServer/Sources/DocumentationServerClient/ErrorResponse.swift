//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 17.12.24.
//

import Foundation
import NIOHTTP1

public struct ErrorResponse: CustomStringConvertible {
    public var description: String {
        if let detail {
            "Error(\(status)): \(detail.value)"
        } else {
            "Error(\(status)): No Detail"
        }
    }
    public typealias Detail = AnyDecodable
    
    let status: Int
    let detail: Detail?
    
    init(status: Int, detail: Detail?) {
        self.status = status
        self.detail = detail
    }
}


extension ErrorResponse: LocalizedError {
    var localizedDescription: String { description }
}

extension ErrorResponse: Decodable {
    enum CodingKeys: CodingKey {
        case status
        case detail
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let statusCode = try container.decode(Int.self, forKey: .status)
        let detail = try container.decodeIfPresent(Detail.self, forKey: .detail)
        
        self.init(status: statusCode, detail: detail)
    }
}




public struct AnyDecodable: Decodable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = ()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let uint = try? container.decode(UInt.self) {
            self.value = uint
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
}
