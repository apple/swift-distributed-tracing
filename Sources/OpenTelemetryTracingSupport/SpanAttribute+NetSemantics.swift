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
    /// - See: NetAttributes
    public enum Net {
        /// - See: NetAttributes
        public static let transport = "net.transport"
        /// - See: NetAttributes
        public static let peerIP = "net.peer.ip"
        /// - See: NetAttributes
        public static let peerPort = "net.peer.port"
        /// - See: NetAttributes
        public static let peerName = "net.peer.name"
        /// - See: NetAttributes
        public static let hostIP = "net.host.ip"
        /// - See: NetAttributes
        public static let hostPort = "net.host.port"
        /// - See: NetAttributes
        public static let hostName = "net.host.name"
    }
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
///
/// - SeeAlso: [OpenTelemetry: General semantic attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/b70565d5a8a13d26c91fb692879dc874d22c3ac8/specification/trace/semantic_conventions/span-general.md) (as of August 2020)
@dynamicMemberLookup
public struct NetAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// Transport protocol used.
        public var transport: SpanAttributeKey<String> { .init(name: SpanAttributeName.Net.transport) }

        /// Remote address of the peer (dotted decimal for IPv4 or RFC5952 for IPv6).
        public var peerIP: SpanAttributeKey<String> { .init(name: SpanAttributeName.Net.peerIP) }

        /// Remote port number as an integer. E.g., 80.
        public var peerPort: SpanAttributeKey<Int> { .init(name: SpanAttributeName.Net.peerPort) }

        /// Remote hostname or similar.
        public var peerName: SpanAttributeKey<String> { .init(name: SpanAttributeName.Net.peerName) }

        /// Like `peerIP` but for the host IP. Useful in case of a multi-IP host.
        public var hostIP: SpanAttributeKey<String> { .init(name: SpanAttributeName.Net.hostIP) }

        /// Like `peerPort` but for the host port.
        public var hostPort: SpanAttributeKey<Int> { .init(name: SpanAttributeName.Net.hostPort) }

        /// Local hostname or similar.
        public var hostName: SpanAttributeKey<String> { .init(name: SpanAttributeName.Net.hostName) }
    }
}
#endif
