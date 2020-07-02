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

public struct HTTPHeadersExtractor: ExtractorProtocol {
    public init() {}

    public func extract(key: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: key)
    }
}

public struct HTTPHeadersInjector: InjectorProtocol {
    public init() {}

    public func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.replaceOrAdd(name: key, value: value)
    }
}
