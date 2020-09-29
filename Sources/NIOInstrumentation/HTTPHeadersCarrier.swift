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

import Instrumentation
import NIOHTTP1

/// Extracts header values from `NIOHTTP1.HTTPHeaders`.
///
/// If multiple entries exist for a given key, their values will be joined according to
/// [HTTP RFC 7230: Field Order](https://httpwg.org/specs/rfc7230.html#rfc.section.3.2.2), returning a comma-separated list
/// of the values.
public struct HTTPHeadersExtractor: ExtractorProtocol {
    public init() {}

    public func extract(key: String, from headers: HTTPHeaders) -> String? {
        let headers = headers
            .lazy
            .filter { $0.name == key }
            .map { $0.value }
        return headers.isEmpty ? nil : headers.joined(separator: ",")
    }
}

/// Injects values into `NIOHTTP1.HTTPHeaders`.
public struct HTTPHeadersInjector: InjectorProtocol {
    public init() {}

    public func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.replaceOrAdd(name: key, value: value)
    }
}
