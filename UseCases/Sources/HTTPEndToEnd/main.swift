//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import Baggage
import Foundation
import Instrumentation
import Logging
import NIO
import NIOHTTP1

// MARK: - Setups

func serviceBootstrap(handler: ChannelHandler) -> ServerBootstrap {
    return ServerBootstrap(group: eventLoopGroup)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.configureHTTPServerPipeline().flatMap {
                channel.pipeline.addHandler(handler)
            }
        }
        .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
}

// MARK: - Fake Tracer

private final class FakeTracer: Instrument {
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(_ context: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = context[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(_ carrier: Carrier, into context: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: FakeTracer.headerName, from: carrier) ?? FakeTracer.defaultTraceID
        context[TraceIDKey.self] = traceID
    }
}

// MARK: - Demo

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

let httpClient = InstrumentedHTTPClient(instrument: FakeTracer(), eventLoopGroupProvider: .createNew)

let orderServiceBootstrap = serviceBootstrap(
    handler: OrderServiceHandler(httpClient: httpClient, instrument: FakeTracer())
)
let storageServiceBootstrap = serviceBootstrap(
    handler: StorageServiceHandler(instrument: FakeTracer())
)

let logger = Logger(label: "FruitStore")

let orderServiceChannel = try orderServiceBootstrap.bind(host: "localhost", port: 8080).wait()
logger.info("🧾 Order service listening on ::1:8080")

let storageServiceChannel = try storageServiceBootstrap.bind(host: "localhost", port: 8081).wait()
logger.info("📦 Storage service listening on ::1:8081")

logger.info("💻 Placing order")
httpClient.get(url: "http://localhost:8080").whenComplete { _ in
    logger.info("💻 Order completed")
}

sleep(5)

try httpClient.syncShutdown()
try orderServiceChannel.close().wait()
try storageServiceChannel.close().wait()
try eventLoopGroup.syncShutdownGracefully()
