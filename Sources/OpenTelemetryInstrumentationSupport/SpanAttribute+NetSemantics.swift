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

import TracingInstrumentation

extension SpanAttributeName {
    public static let netTransport = "net.transport"
    public static let netPeerIP = "net.peer.ip"
    public static let netPeerPort = "net.peer.port"
    public static let netPeerName = "net.peer.name"
    public static let netHostIP = "net.host.ip"
    public static let netHostPort = "net.host.port"
    public static let netHostName = "net.host.name"
}

#if swift(>=5.2)
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
        public var transport: SpanAttributeKey<String> { .init(name: SpanAttributeName.netTransport) }

        /// Remote address of the peer (dotted decimal for IPv4 or RFC5952 for IPv6).
        public var peerIP: SpanAttributeKey<String> { .init(name: SpanAttributeName.netPeerIP) }

        /// Remote port number as an integer. E.g., 80.
        public var peerPort: SpanAttributeKey<Int> { .init(name: SpanAttributeName.netPeerPort) }

        /// Remote hostname or similar.
        public var peerName: SpanAttributeKey<String> { .init(name: SpanAttributeName.netPeerName) }

        /// Like `peerIP` but for the host IP. Useful in case of a multi-IP host.
        public var hostIP: SpanAttributeKey<String> { .init(name: SpanAttributeName.netHostIP) }

        /// Like `peerPort` but for the host port.
        public var hostPort: SpanAttributeKey<Int> { .init(name: SpanAttributeName.netHostPort) }

        /// Local hostname or similar.
        public var hostName: SpanAttributeKey<String> { .init(name: SpanAttributeName.netHostName) }
    }
}
#endif
