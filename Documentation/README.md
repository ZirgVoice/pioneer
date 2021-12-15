---
icon: home
title: Welcome
---

# Welcome to Pioneer

[Pioneer](https://github.com/d-exclaimation/pioneer) is an easy to use Swift GraphQL :unicorn_face: server built for Vapor that works with any GraphQL schema built with [GraphQLSwift/GraphQL](https://github.com/GraphQLSwift/GraphQL) or using libraries that uses that package.

![Pioneer](pioneer-banner.png)

No complicated setup required to use Pioneer. It is as easy as plugging it into an existing Vapor application.

Pioneer will configure all the necessary things to build a GraphQL API such as:

- Handling operations through HTTP :incoming_envelope: (**GET** and **POST**)
- Adding GraphQL IDE like [graphql-playground](https://github.com/graphql/graphql-playground)
- Handling subscriptions through WebSocket :dove_of_peace:.

## Quick Start

You can add Pioneer into any existing Vapor application with any GraphQL schema library made from [GraphQLSwift/GraphQL](https://github.com/GraphQLSwift/GraphQL) like [Graphiti](https://github.com/GraphQLSwift/Graphiti).

!!! :zap: [Getting Started](./guides/getting-started/setup.md) :zap:
Get up to speed with Pioneer with a full example by checking out the guide.

[!ref Getting Started](./guides/getting-started/setup.md)
!!!

Go to the `main.swift` or any Swift file where you apply your Vapor routing like your `routes.swift` file.

Next, contruct an new Pioneer instance with your flavour of configuration and apply it to any `RoutesBuilder`.

+++ main.swift

```swift
import Vapor
import Pioneer // <- import the package
import Graphiti

let app = try Application(.detect())

let schema: Schema<Void, Resolver> = ... // <- Schema built by Graphiti

let resolver: Resolver = ... // <- Custom resolver struct

let server = Pioneer(
    schema: schema,
    resolver: resolver,
    websocketProtocol: .graphqlWs
)

server.applyMiddleware(on: app) // <- Apply routing to the Application directly

defer {
    app.shutdown()
}

try app.run()
```

+++ routes.swift

```swift
import Vapor
import Pioneer // <- import the package
import Graphiti

let server = Pioneer(...)

func routes(_ app: Application) throws {
    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    server.applyMiddleware(on: app) // <- Apply routing to the Application directly
}

```

+++