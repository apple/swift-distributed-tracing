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

import Tracing

extension SpanAttributeName {
    /// - See: RPCAttributes
    public enum RPC {
        /// - See: RPCAttributes
        public static let system = "rpc.system"
        /// - See: RPCAttributes
        public static let service = "rpc.service"
        /// - See: RPCAttributes
        public static let method = "rpc.method"
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic conventions for RPC spans.
    public var rpc: RPCAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Semantic conventions for RPC spans as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: Semantic conventions for RPC spans](https://github.com/open-telemetry/opentelemetry-specification/blob/b70565d5a8a13d26c91fb692879dc874d22c3ac8/specification/trace/semantic_conventions/rpc.md) (as of August 2020)
@dynamicMemberLookup
public struct RPCAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// A string identifying the remoting system, e.g., "grpc", "java_rmi" or "wcf".
        public var system: SpanAttributeKey<String> { .init(name: SpanAttributeName.RPC.system) }

        /// The full name of the service being called, including its package name, if applicable.
        public var service: SpanAttributeKey<String> { .init(name: SpanAttributeName.RPC.service) }

        /// The name of the method being called, must be equal to the $method part in the span name.
        public var method: SpanAttributeKey<String> { .init(name: SpanAttributeName.RPC.method) }
    }
}
#endif
