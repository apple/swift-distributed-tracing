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
    public static let peerService = "peer.service"
}

#if swift(>=5.2)
extension SpanAttributes {
    /// General semantic attributes.
    public var peer: PeerAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Peer-related semantic conventions as defined in the OpenTelemetry spec.
@dynamicMemberLookup
public struct PeerAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// The service.name of the remote service. SHOULD be equal to the actual service.name resource attribute of the remote service if any.
        public var service: SpanAttributeKey<String> { .init(name: SpanAttributeName.peerService) }
    }
}
#endif
