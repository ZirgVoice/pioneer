//
//  Pioneer+WebSocket.swift
//  Pioneer
//
//  Created by d-exclaimation on 11:36 AM.
//  Copyright © 2021 d-exclaimation. All rights reserved.
//

import Foundation
import Vapor
import GraphQL

typealias SwiftTimer = Foundation.Timer

extension Pioneer {
    func applyWebSocket(on router: RoutesBuilder, at path: [PathComponent] = ["graphql", "websocket"]) {
        router.get(path) { req throws -> Response in
            let protocolHeader: [String] = req.headers[.secWebSocketProtocol]
            guard let _ = protocolHeader.filter(websocketProtocol.isValid).first else {
                throw GraphQLError(ResolveError.unsupportedProtocol)
            }
            return req.webSocket { req, ws in
                let ctx = contextBuilder(req)
                let process = Process(ws: ws, ctx: ctx, req: req)

                let timer = SwiftTimer.scheduledTimer(withTimeInterval: 12, repeats: true) { timer in
                    ws.send(websocketProtocol.keepAliveMessage)
                }

                ws.onText { _, txt in
                    Task.init {
                        await onMessage(process: process, timer: timer, txt: txt)
                    }
                }

                ws.onClose.whenComplete { _ in
                    onEnd(pid: process.id, timer: timer)
                }
            }
        }
    }

    func onMessage(process: Process, timer: SwiftTimer, txt: String) async  -> Void {
        guard let data = txt.data(using: .utf8) else {
            // Shouldn't accept any message that aren't utf8 string
            // -> Close with 1003 code
            await process.close(code: .unacceptableData)
            return
        }

        switch websocketProtocol.parse(data) {

        // Initial sub-protocol handshake established
        // Dispatch process to probe so it can start accepting operations
        // Timer fired here to keep connection alive by sub-protocol standard
        case .initial:
            await probe.task(with: .connect(process: process))
            timer.fire()
            websocketProtocol.initialize(ws: process.ws)

        // Ping is for requesting server to send a keep alive message
        case .ping:
            process.send(websocketProtocol.keepAliveMessage)

        // Explicit message to terminate connection to deallocate resources, stop timer, and close connection
        case .terminate:
            await probe.task(with: .disconnect(pid: process.id))
            timer.invalidate()
            await process.close(code: .goingAway)

        // Start -> Long running operation
        case .start(oid: let oid, gql: let gql):
            // Introspection guard
            guard case .some(true) = try? allowed(from: gql) else {
                let err = GraphQLMessage.errors(id: oid, type: websocketProtocol.error, [
                    .init(message: "GraphQL introspection is not allowed by Pioneer, but the query contained __schema or __type.")
                ])
                return process.send(err.jsonString)
            }
            await probe.task(with: .start(
                pid: process.id,
                oid: oid,
                gql: gql,
                ctx: process.ctx
            ))

        // Once -> Short lived operation
        case .once(oid: let oid, gql: let gql):
            // Introspection guard
            guard case .some(true) = try? allowed(from: gql) else {
                let err = GraphQLMessage.errors(id: oid, type: websocketProtocol.error, [
                    .init(message: "GraphQL introspection is not allowed by Pioneer, but the query contained __schema or __type.")
                ])
                return process.send(err.jsonString)
            }
            await probe.task(with: .once(
                pid: process.id,
                oid: oid,
                gql: gql,
                ctx: process.ctx
            ))

        // Stop -> End any running operation
        case .stop(oid: let oid):
            await probe.task(with: .stop(
                pid: process.id,
                oid: oid
            ))

        // Error in validation should notify that no operation will be run, does not close connection
        case .error(oid: let oid, message: let message):
            let err = GraphQLMessage.errors(id: oid, type: websocketProtocol.error, [.init(message: message)])
            process.send(err.jsonString)

        // Fatal error is an event trigger when message given in unacceptable by protocol standard
        // This message if processed any further will cause securities vulnerabilities, thus connection should be closed
        case .fatal(message: let message):
            let err = GraphQLMessage.errors(type: websocketProtocol.error, [.init(message: message)])
            process.send(err.jsonString)

            // Deallocation of resources
            await probe.task(with: .disconnect(pid: process.id))
            timer.invalidate()
            await process.close(code: .policyViolation)

        case .ignore:
            break
        }
    }

    func onEnd(pid: UUID, timer: SwiftTimer) -> Void {
        probe.tell(with: .disconnect(pid: pid))
        timer.invalidate()
    }
}