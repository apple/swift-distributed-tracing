//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Tracing

extension SpanAttributeName {
    /// - SeeAlso: MessagingAttributes
    public enum Messaging {
        /// - SeeAlso: MessagingAttributes
        public static let system = "messaging.system"
        /// - SeeAlso: MessagingAttributes
        public static let destination = "messaging.destination"
        /// - SeeAlso: MessagingAttributes
        public static let destinationKind = "messaging.destination_kind"
        /// - SeeAlso: MessagingAttributes
        public static let tempDestination = "messaging.temp_destination"
        /// - SeeAlso: MessagingAttributes
        public static let `protocol` = "messaging.protocol"
        /// - SeeAlso: MessagingAttributes
        public static let protocolVersion = "messaging.protocol_version"
        /// - SeeAlso: MessagingAttributes
        public static let url = "messaging.url"
        /// - SeeAlso: MessagingAttributes
        public static let messageID = "messaging.message_id"
        /// - SeeAlso: MessagingAttributes
        public static let conversationID = "messaging.conversation_id"
        /// - SeeAlso: MessagingAttributes
        public static let messagePayloadSizeBytes = "messaging.message_payload_size_bytes"
        /// - SeeAlso: MessagingAttributes
        public static let messagePayloadCompressedSizeBytes = "messaging.message_payload_compressed_size_bytes"
        /// - SeeAlso: MessagingAttributes
        public static let operation = "messaging.operation"

        /// - SeeAlso: MessagingAttributes.KafkaAttributes
        public enum Kafka {
            /// - SeeAlso: MessagingAttributes.KafkaAttributes
            public static let messageKey = "messaging.kafka.message_key"
            /// - SeeAlso: MessagingAttributes.KafkaAttributes
            public static let consumerGroup = "messaging.kafka.consumer_group"
            /// - SeeAlso: MessagingAttributes.KafkaAttributes
            public static let clientID = "messaging.kafka.client_id"
            /// - SeeAlso: MessagingAttributes.KafkaAttributes
            public static let partition = "messaging.kafka.partition"
            /// - SeeAlso: MessagingAttributes.KafkaAttributes
            public static let tombstone = "messaging.kafka.tombstone"
        }
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic conventions for messaging system spans.
    public var messaging: MessagingAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Semantic conventions for messaging system spans as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: Messaging Attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/messaging.md#messaging-attributes)
@dynamicMemberLookup
public struct MessagingAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    // MARK: - General

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// A string identifying the messaging system.
        public var system: Key<String> { .init(name: SpanAttributeName.Messaging.system) }

        /// The message destination name. This might be equal to the span name but is required nevertheless.
        public var destination: Key<String> { .init(name: SpanAttributeName.Messaging.destination) }

        /// The kind of message destination.
        public var destinationKind: Key<String> { .init(name: SpanAttributeName.Messaging.destinationKind) }

        /// A boolean that is true if the message destination is temporary.
        ///
        /// - SeeAlso: [OpenTelemetry: Temporary Destinations](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/messaging.md#temporary-destinations)
        public var tempDestination: Key<Bool> { .init(name: SpanAttributeName.Messaging.tempDestination) }

        /// The name of the transport protocol.
        public var `protocol`: Key<String> { .init(name: SpanAttributeName.Messaging.protocol) }

        /// The version of the transport protocol.
        public var protocolVersion: Key<String> { .init(name: SpanAttributeName.Messaging.protocolVersion) }

        /// The connection string.
        public var url: Key<String> { .init(name: SpanAttributeName.Messaging.url) }

        /// A value used by the messaging system as an identifier for the message, represented as a string.
        public var messageID: Key<String> { .init(name: SpanAttributeName.Messaging.messageID) }

        /// The conversation ID identifying the conversation to which the message belongs, represented as a string. Sometimes called "Correlation ID".
        ///
        /// - SeeAlso: [OpenTelemetry: Conversations](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/messaging.md#conversations)
        public var conversationID: Key<String> { .init(name: SpanAttributeName.Messaging.conversationID) }

        /// The (uncompressed) size of the message payload in bytes. Also use this attribute if it is unknown whether the compressed or uncompressed
        /// payload size is reported.
        public var messagePayloadSizeBytes: Key<Int> {
            .init(name: SpanAttributeName.Messaging.messagePayloadSizeBytes)
        }

        /// The compressed size of the message payload in bytes.
        public var messagePayloadCompressedSizeBytes: Key<Int> {
            .init(name: SpanAttributeName.Messaging.messagePayloadCompressedSizeBytes)
        }

        /// A string identifying the kind of message consumption as defined in the [Operation names](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/messaging.md#operation-names) section.
        /// If the operation is "send", this attribute MUST NOT be set, since the operation can be inferred from the span kind in that case.
        public var operation: Key<String> { .init(name: SpanAttributeName.Messaging.operation) }
    }

    // MARK: - Kafka

    /// Semantic conventions for Kafka spans.
    public var kafka: KafkaAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for Kafka spans as defined in the OpenTelemetry spec.
    ///
    /// - SeeAlso: [OpenTelemetry: Kafka Attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/messaging.md#apache-kafka)
    public struct KafkaAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// Message keys in Kafka are used for grouping alike messages to ensure they're processed on the same partition.
            /// They differ from `messaging.message_id` in that they're not unique. If the key is `null`, the attribute MUST NOT be set.
            public var messageKey: Key<String> { .init(name: SpanAttributeName.Messaging.Kafka.messageKey) }

            /// Name of the Kafka Consumer Group that is handling the message. Only applies to consumers, not producers.
            public var consumerGroup: Key<String> { .init(name: SpanAttributeName.Messaging.Kafka.consumerGroup) }

            /// Client Id for the Consumer or Producer that is handling the message.
            public var clientID: Key<String> { .init(name: SpanAttributeName.Messaging.Kafka.clientID) }

            /// Partition the message is sent to.
            public var partition: Key<Int> { .init(name: SpanAttributeName.Messaging.Kafka.partition) }

            /// A boolean that is true if the message is a tombstone.
            public var tombstone: Key<Bool> { .init(name: SpanAttributeName.Messaging.Kafka.tombstone) }
        }
    }
}
#endif
