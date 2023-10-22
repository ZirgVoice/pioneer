//  PubSub.swift
//
//
//  Created by d-exclaimation on 20/06/22.
//

/// A base protocol for pub/sub data structure that utilize async stream
public protocol PubSub {
    /// Returns a new AsyncStream with the correct type and for a specific trigger
    ///
    /// - Parameters:
    ///   - type: DataType of this AsyncStream
    ///   - trigger: The topic string used to differentiate what data should this stream be accepting
    func asyncStream<DataType: Sendable & Decodable>(_ type: DataType.Type, for trigger: String) -> AsyncThrowingStream<DataType, Error>

    /// Publish a new data into the pubsub for a specific trigger.
    /// - Parameters:
    ///   - trigger: The trigger this data will be published to
    ///   - payload: The data being emitted
    func publish<DataType: Sendable & Encodable>(for trigger: String, payload: DataType) async

    /// Close a specific trigger and deallocate every consumer of that trigger
    /// - Parameter trigger: The trigger this call takes effect on
    func close(for trigger: String) async
}


/// Type Conversion Error for the PubSub
public struct PubSubConversionError: Error, @unchecked Sendable {
    /// The detailed reasoning why conversion failed
    public var reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var localizedDescription: String {
        "PubSubConversionError: \"\(reason)\""
    }
}