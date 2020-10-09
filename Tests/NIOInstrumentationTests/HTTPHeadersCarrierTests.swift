//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOHTTP1
import NIOInstrumentation
import XCTest

final class HTTPHeadersCarrierTests: XCTestCase {
    func testExtractSingleHeader() {
        let headers: HTTPHeaders = [
            "tracestate": "vendorname1=opaqueValue1,vendorname2=opaqueValue2",
            "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01",
        ]

        let extractor = HTTPHeadersExtractor()

        XCTAssertEqual(
            extractor.extract(key: "tracestate", from: headers),
            "vendorname1=opaqueValue1,vendorname2=opaqueValue2"
        )

        XCTAssertEqual(
            extractor.extract(key: "traceparent", from: headers),
            "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01"
        )
    }

    func testExtractNoHeader() {
        let extractor = HTTPHeadersExtractor()

        XCTAssertNil(extractor.extract(key: "test", from: .init()))
    }

    func testExtractEmptyHeader() {
        let extractor = HTTPHeadersExtractor()

        XCTAssertEqual(extractor.extract(key: "test", from: ["test": ""]), "")
    }

    func testExtractMultipleHeadersOfSameName() {
        let headers: HTTPHeaders = [
            "tracestate": "vendorname1=opaqueValue1",
            "traceparent": "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01",
            "tracestate": "vendorname2=opaqueValue2",
        ]

        let extractor = HTTPHeadersExtractor()

        XCTAssertEqual(
            extractor.extract(key: "tracestate", from: headers),
            "vendorname1=opaqueValue1,vendorname2=opaqueValue2"
        )

        XCTAssertEqual(
            extractor.extract(key: "traceparent", from: headers),
            "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01"
        )
    }
}
