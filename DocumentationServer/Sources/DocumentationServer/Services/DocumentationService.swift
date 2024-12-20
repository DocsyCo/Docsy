//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 08.12.24.
//

import Foundation
import Hummingbird

public struct DocumentationServiceID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let repository = DocumentationServiceID(rawValue: "repository")
    public static let storage = DocumentationServiceID(rawValue: "storage")
}

public enum ServiceFunction {
    case endpoint
    case middleware(DocumentationServiceID)
}

public protocol DocumentationService {
    typealias Endpoints = RouteCollection<BasicRequestContext>
    static var id: DocumentationServiceID { get }
    
    func endpoints() -> Endpoints
}
