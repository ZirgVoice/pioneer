//
//  Pioneer+Http.swift
//  Pioneer
//
//  Created by d-exclaimation on 11:34 AM.
//

import Vapor
import enum GraphQL.OperationType
import enum GraphQL.Map
import struct GraphQL.GraphQLError
import class GraphQL.GraphQLJSONEncoder


extension Pioneer {
    /// Vapor-based HTTP Context builder
    public typealias VaporHTTPContext = @Sendable (Request, Response) async throws -> Context

    /// Common Handler for GraphQL through HTTP
    /// - Parameter req: The HTTP request being made
    /// - Returns: A response from the GraphQL operation execution properly formatted
    public func httpHandler(req: Request, context: @escaping VaporHTTPContext) async throws -> Response {
        try await httpHandler(req: req, using: GraphQLJSONEncoder(), context: context)
    }
    
    /// Common Handler for GraphQL through HTTP
    /// - Parameters:
    ///   - req: The HTTP request being made
    ///   - using: The custom content encoder
    /// - Returns: A response from the GraphQL operation execution properly formatted
    public func httpHandler(req: Request, using encoder: ContentEncoder, context: @escaping VaporHTTPContext) async throws -> Response {
        let res = Response()
        do {
            // Parsing GraphQLRequest and Context 
            let gql = try req.graphql
            let context = try await context(req, res)
            let httpReq = HTTPGraphQLRequest(request: gql, headers: req.headers, method: req.method)

            // Executing into GraphQLResult
            let httpRes = await executeHTTPGraphQLRequest(for: httpReq, with: context, using: req.eventLoop)
            try res.content.encode(httpRes.result, using: encoder)
            res.status = httpRes.status
            return res
        } catch let error as AbortError {
            return try error.response(using: res)
        } catch {
            return try error.graphql.response(with: .internalServerError)
        }
    }
}
