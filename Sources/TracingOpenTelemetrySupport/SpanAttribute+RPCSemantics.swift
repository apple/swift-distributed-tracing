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

        /// - See: RPCAttributes.GRPCAttributes
        public enum GRPC {
            /// - See: RPCAttributes.GRPCAttributes
            public static let statusCode = "rpc.grpc.status_code"
        }
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
/// - SeeAlso: [OpenTelemetry: Semantic conventions for RPC spans](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/rpc.md)
@dynamicMemberLookup
public struct RPCAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// A string identifying the remoting system, e.g., "grpc", "java_rmi" or "wcf".
        public var system: Key<String> { .init(name: SpanAttributeName.RPC.system) }

        /// The full name of the service being called, including its package name, if applicable.
        public var service: Key<String> { .init(name: SpanAttributeName.RPC.service) }

        /// The name of the method being called, must be equal to the $method part in the span name.
        public var method: Key<String> { .init(name: SpanAttributeName.RPC.method) }
    }

    /// Semantic conventions for gRPC spans.
    public var gRPC: GRPCAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic concentions for gRPC spans as defined in the OpenTelemetry spec.
    ///
    /// - SeeAlso: [OpenTelemetry: Semantic conventions for gRPC spans](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/rpc.md#grpc)
    public struct GRPCAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The [numeric status code](https://github.com/grpc/grpc/blob/v1.33.2/doc/statuscodes.md) of the gRPC request.
            public var statusCode: Key<Int> { .init(name: SpanAttributeName.RPC.GRPC.statusCode) }
        }
    }
}
#endif
