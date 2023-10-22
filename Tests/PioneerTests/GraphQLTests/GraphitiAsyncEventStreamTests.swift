//
//  GraphitiAsyncEventStreamTests.swift
//  Pioneer
//
//  Created by d-exclaimation on 7:17 PM.
//  Copyright © 2021 d-exclaimation. All rights reserved.
//

import Graphiti
import GraphQL
import NIO
@testable import Pioneer
import XCTest

final class GraphitiTests: XCTestCase {
    /// Simple message type with a custom computed properties
    struct Message: Codable, Identifiable {
        var id: String = UUID().uuidString
        var content: String

        struct Arg: Codable {
            var formatting: String
        }

        func description(context _: Void, arguments: Arg) async throws -> String {
            switch arguments.formatting.lowercased() {
            case "inline":
                return "msg(\(id)): \(content)"
            default:
                return """
                Message:
                id -> \(id)
                > \(content)
                """
            }
        }
    }

    /// Simple Test Resolver with a sync query, async throwing mutation, and async throwing subscriptions
    struct Resolver {
        let pubsub = AsyncPubSub()

        func hello(context _: Void, arguments _: NoArguments) -> String {
            "Hello GraphQL!!"
        }

        struct Arg1: Codable {
            var string: String
        }

        func randomMessage(context _: Void, arguments: Arg1) async throws -> Message {
            let message = Message(content: arguments.string)
            await pubsub.publish(for: "*", payload: message)
            return message
        }

        func onMessage(context _: Void, arguments _: NoArguments) -> EventStream<Message> {
            pubsub.asyncStream(for: "*").toEventStream()
        }
    }

    private let resolver: Resolver = .init()
    private var group = MultiThreadedEventLoopGroup(numberOfThreads: 4)

    override func tearDownWithError() throws {
        try group.syncShutdownGracefully()
    }

    /// Subscription through AsyncSequence's AsyncEventStream
    /// 1. Should properly parse Schema
    /// 2. Should be able to call subscribe and get the SubscriptionResult
    /// 3. Should be able to get EventStream and AsyncStream
    /// 4. Should get all passed messages when consuming
    /// 5. Should get those messages in the correct order and format
    func testAsyncSequenceSubscription() throws {
        let schema = try Schema<Resolver, Void> {
            Type(Message.self) {
                Field("id", at: \.id)
                Field("content", at: \.content)
                Field("description", at: Message.description) {
                    Argument("formatting", at: \.formatting)
                }
            }

            Query {
                Field("hello", at: Resolver.hello)
            }

            Mutation {
                Field("randomMessage", at: Resolver.randomMessage) {
                    Argument("content", at: \.string)
                }
            }

            Subscription {
                SubscriptionField("onMessage", as: Message.self, atSub: Resolver.onMessage)
            }
        }

        let start = Date()

        let query = """
        subscription {
            onMessage {
                id, content       
            }
        }
        """

        // -- Performing Subscriptions --

        let subscriptionResult = try schema
            .subscribe(request: query, resolver: resolver, context: (), eventLoopGroup: group)
            .wait()

        guard let subscription = subscriptionResult.stream else {
            return XCTFail(subscriptionResult.errors.description)
        }

        guard let asyncStream = subscription.asyncStream() else {
            return XCTFail("Stream failed to be casted into proper types \(subscription))")
        }

        // -- End --

        let expectation = XCTestExpectation(description: "Received a single message")

        // -- Consuming stream --

        let task = Task.init {
            for try await future in asyncStream {
                let message = try await future.get()
                let expected = GraphQLResult(data: [
                    "onMessage": [
                        "id": "bob",
                        "content": "Bob",
                    ],
                ])
                if message == expected {
                    expectation.fulfill()
                }
                break
            }
        }

        // -- End --

        Task.init {
            try await Task.sleep(nanoseconds: 200_000_000)
            await resolver.pubsub.publish(for: "*", payload: Message(id: "bob", content: "Bob"))
            await resolver.pubsub.publish(for: "*", payload: Message(id: "bob2", content: "Bob2"))
        }

        wait(for: [expectation], timeout: 10)
        task.cancel()
        print(abs(start.timeIntervalSinceNow) * 1000)
    }
}
