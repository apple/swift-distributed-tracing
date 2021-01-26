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

        /// - See: NetAttributes.PeerAttributes
        public enum Peer {
            /// - See: NetAttributes.PeerAttributes
            public static let ip = "net.peer.ip"
            /// - See: NetAttributes.PeerAttributes
            public static let port = "net.peer.port"
            /// - See: NetAttributes.PeerAttributes
            public static let name = "net.peer.name"
        }

        /// - See: NetAttributes.HostAttributes
        public enum Host {
            /// - See: NetAttributes.HostAttributes
            public static let ip = "net.host.ip"
            /// - See: NetAttributes.HostAttributes
            public static let port = "net.host.port"
            /// - See: NetAttributes.HostAttributes
            public static let name = "net.host.name"
        }
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

/// Network related semantic conventions as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: General semantic attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/span-general.md#general-network-connection-attributes)
@dynamicMemberLookup
public struct NetAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    // MARK: - General

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// Transport protocol used.
        public var transport: Key<String> { .init(name: SpanAttributeName.Net.transport) }
    }

    // MARK: - Peer

    /// Semantic network peer attributes.
    public var peer: PeerAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic network peer attributes.
    public struct PeerAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// Remote address of the peer (dotted decimal for IPv4 or RFC5952 for IPv6).
            public var ip: Key<String> { .init(name: SpanAttributeName.Net.Peer.ip) }

            /// Remote port number as an integer. E.g., 80.
            public var port: Key<Int> { .init(name: SpanAttributeName.Net.Peer.port) }

            /// Remote hostname or similar.
            public var name: Key<Int> { .init(name: SpanAttributeName.Net.Peer.name) }
        }
    }

    // MARK: - Host

    /// Semantic network host attributes.
    public var host: HostAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic network host attributes.
    public struct HostAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// Like `peer.ip` but for the host IP. Useful in case of a multi-IP host.
            public var ip: Key<String> { .init(name: SpanAttributeName.Net.Host.ip) }

            /// Like `peer.port` but for the host port.
            public var port: Key<Int> { .init(name: SpanAttributeName.Net.Host.port) }

            /// Local hostname or similar.
            public var name: Key<String> { .init(name: SpanAttributeName.Net.Host.name) }
        }
    }
}
#endif
