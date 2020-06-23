import AsyncHTTPClient
import Baggage
import Foundation
import Instrumentation
import Logging
import NIO
import NIOHTTP1

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

// MARK: - Setups

func serviceBootstrap(handler: ChannelHandler) -> ServerBootstrap {
    ServerBootstrap(group: eventLoopGroup)
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

private struct FakeTracer: InstrumentProtocol {
    enum TraceID: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"

    func inject(from baggage: BaggageContext, into headers: inout HTTPHeaders) {
        guard let traceID = baggage[TraceID.self] else { return }
        headers.replaceOrAdd(name: Self.headerName, value: traceID)
    }

    func extract(from headers: HTTPHeaders, into baggage: inout BaggageContext) {
        let traceID = headers.first(where: { $0.0 == Self.headerName })?.1 ?? UUID().uuidString
        baggage[TraceID.self] = traceID
    }
}
