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
    /// - See: GRPCAttributes
    public enum GRPC {
        /// - See: GRPCAttributes
        public static let messageType = "message.type"
        /// - See: GRPCAttributes
        public static let messageID = "message.id"
        /// - See: GRPCAttributes
        public static let messageCompressedSize = "message.compressed_size"
        /// - See: GRPCAttributes
        public static let messageUncompressedSize = "message.uncompressed_size"
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic conventions for gRPC spans.
    public var gRPC: GRPCAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Semantic conventions for gRPC spans as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: Semantic conventions for gRPC spans](https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/rpc.md#grpc) (as of August 2020)
@dynamicMemberLookup
public struct GRPCAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// The type of message, e.g. "SENT" or "RECEIVED".
        public var messageType: SpanAttribute.Key<String> { .init(name: SpanAttributeName.GRPC.messageType) }

        /// The message id calculated as two different counters starting from 1, one for sent messages and one for received messages.
        public var messageID: SpanAttribute.Key<Int> { .init(name: SpanAttributeName.GRPC.messageID) }

        /// The compressed message size in bytes.
        public var messageCompressedSize: SpanAttribute.Key<Int> {
            .init(name: SpanAttributeName.GRPC.messageCompressedSize)
        }

        /// The uncompressed message size in bytes.
        public var messageUncompressedSize: SpanAttribute.Key<Int> {
            .init(name: SpanAttributeName.GRPC.messageUncompressedSize)
        }
    }
}
#endif
