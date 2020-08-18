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

#if swift(>=5.2)
import TracingInstrumentation

extension SpanAttributes {
    /// Semantic network attributes.
    public var net: NetAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Network-related semantic conventions as defined in the OpenTelemetry spec.
@dynamicMemberLookup
public struct NetAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// Transport protocol used.
        public var transport: SpanAttributeKey<String> { "net.transport" }

        /// Remote address of the peer (dotted decimal for IPv4 or RFC5952 for IPv6).
        public var peerIP: SpanAttributeKey<String> { "net.peer.ip" }

        /// Remote port number as an integer. E.g., 80.
        public var peerPort: SpanAttributeKey<Int> { "net.peer.port" }

        /// Remote hostname or similar.
        public var peerName: SpanAttributeKey<String> { "net.peer.name" }

        /// Like `peerIP` but for the host IP. Useful in case of a multi-IP host.
        public var hostIP: SpanAttributeKey<String> { "net.host.ip" }

        /// Like `peerPort` but for the host port.
        public var hostPort: SpanAttributeKey<Int> { "net.host.port" }

        /// Local hostname or similar.
        public var hostName: SpanAttributeKey<String> { "net.host.name" }
    }
}
#endif
