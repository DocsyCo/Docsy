import Foundation
import SwiftDocC

extension Message: Codable {
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(MessageType.self, forKey: .type)
        self.data = try decodeDataIfPresent(for: type, from: container)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(data, forKey: .data)
    }
}

fileprivate func decodeDataIfPresent(
    for type: MessageType,
    from container: KeyedDecodingContainer<Message.CodingKeys>
) throws -> AnyCodable? {
    switch type {
    case .navigation:
        return AnyCodable(try container.decodeIfPresent(URL.self, forKey: .data))
    default:
        return AnyCodable(try container.decodeIfPresent(AnyCodable.self, forKey: .data))
    }
}
