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
///
/// - SeeAlso: [OpenTelemetry: General remote service attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/b70565d5a8a13d26c91fb692879dc874d22c3ac8/specification/trace/semantic_conventions/span-general.md#general-remote-service-attributes) (as of August 2020)
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
