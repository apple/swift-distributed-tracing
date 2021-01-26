//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import Instrumentation
import Tracing
import TracingOpenTelemetrySupport
import XCTest

final class SpanAttributeSemanticsTests: XCTestCase {
    func testDynamicMemberLookupForEachNamespace() {
        #if swift(>=5.2)
        var attributes: SpanAttributes = [:]

        attributes.db.system = "postgresql"
        XCTAssertEqual(attributes.db.system, "postgresql")

        attributes.db.mssql.instanceName = "test"
        XCTAssertEqual(attributes.db.mssql.instanceName, "test")

        attributes.db.cassandra.keyspace = "test"
        XCTAssertEqual(attributes.db.cassandra.keyspace, "test")

        attributes.db.hbase.namespace = "test"
        XCTAssertEqual(attributes.db.hbase.namespace, "test")

        attributes.db.redis.databaseIndex = 1
        XCTAssertEqual(attributes.db.redis.databaseIndex, 1)

        attributes.db.mongodb.collection = "test"
        XCTAssertEqual(attributes.db.mongodb.collection, "test")

        attributes.db.sql.table = "test"
        XCTAssertEqual(attributes.db.sql.table, "test")

        attributes.endUser.id = "steve"
        XCTAssertEqual(attributes.endUser.id, "steve")

        attributes.exception.type = "SomeError"
        XCTAssertEqual(attributes.exception.type, "SomeError")

        attributes.faas.trigger = "datasource"
        XCTAssertEqual(attributes.faas.trigger, "datasource")

        attributes.faas.document.collection = "collection"
        XCTAssertEqual(attributes.faas.document.collection, "collection")

        attributes.http.method = "GET"
        XCTAssertEqual(attributes.http.method, "GET")

        attributes.http.server.route = "/users/:userID?"
        XCTAssertEqual(attributes.http.server.route, "/users/:userID?")

        attributes.messaging.system = "kafka"
        XCTAssertEqual(attributes.messaging.system, "kafka")

        attributes.messaging.kafka.partition = 2
        XCTAssertEqual(attributes.messaging.kafka.partition, 2)

        attributes.net.transport = "IP.TCP"
        XCTAssertEqual(attributes.net.transport, "IP.TCP")

        attributes.net.peer.ip = "127.0.0.1"
        XCTAssertEqual(attributes.net.peer.ip, "127.0.0.1")

        attributes.net.host.ip = "127.0.0.1"
        XCTAssertEqual(attributes.net.host.ip, "127.0.0.1")

        attributes.peer.service = "hotrod"
        XCTAssertEqual(attributes.peer.service, "hotrod")

        attributes.rpc.system = "grpc"
        XCTAssertEqual(attributes.rpc.system, "grpc")

        attributes.rpc.gRPC.statusCode = 0
        XCTAssertEqual(attributes.rpc.gRPC.statusCode, 0)
        #endif
    }
}
