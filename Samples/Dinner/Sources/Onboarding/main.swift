//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OpenTelemetry open source project
//
// Copyright (c) 2021 Moritz Lang and the Swift OpenTelemetry project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import OpenTelemetry
import OtlpGRPCSpanExporting
import Tracing

// ==== ----------------------------------------------------------------------------------------------------------------

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = .trace
    return handler
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: - Configure OTel

let exporter = OtlpGRPCSpanExporter(config: OtlpGRPCSpanExporter.Config(eventLoopGroup: group))
let processor = OTel.SimpleSpanProcessor(exportingTo: exporter)
let otel = OTel(serviceName: "DinnerService", eventLoopGroup: group, processor: processor)

let otelChopping1 = OTel(serviceName: "ChoppingService-1", eventLoopGroup: group, processor: processor)
let otelChopping2 = OTel(serviceName: "ChoppingService-2", eventLoopGroup: group, processor: processor)

// First start `OTel`, then bootstrap the instrumentation system.
// This makes sure that all components are ready to begin handling spans.
try otel.start().wait()
try otelChopping1.start().wait()
try otelChopping2.start().wait()

// By bootstrapping the instrumentation system, our dependencies
// compatible with "Swift Distributed Tracing" will also automatically
// use the "OpenTelemetry Swift" Tracer 🚀.
InstrumentationSystem.bootstrap(otel.tracer())

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: - Run the sample app

let dinner = try await makeDinner()

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: - Shutdown

// Wait a second to let the exporter finish before shutting down.
sleep(2)

try otel.shutdown().wait()
try group.syncShutdownGracefully()
