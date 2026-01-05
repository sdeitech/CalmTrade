//
//  SocketEnvelope.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/10/25.
//


// SocketMessage.swift
import Foundation

struct SocketEnvelope<Payload: Codable>: Codable {
    let key: String
    let data: Payload?
}

private struct EmptyPayload: Codable {}

extension JSONEncoder {
    static let socketEncoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        return enc
    }()
}

extension JSONDecoder {
    static let socketDecoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return dec
    }()
}
