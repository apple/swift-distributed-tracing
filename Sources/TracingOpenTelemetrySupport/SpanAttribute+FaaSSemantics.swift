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
    /// - SeeAlso: FaaSAttributes
    public enum FaaS {
        /// - SeeAlso: FaaSAttributes
        public static let trigger = "faas.trigger"
        /// - SeeAlso: FaaSAttributes
        public static let execution = "faas.execution"
        /// - SeeAlso: FaaSAttributes
        public static let time = "faas.time"
        /// - SeeAlso: FaaSAttributes
        public static let cron = "faas.cron"
        /// - SeeAlso: FaaSAttributes
        public static let coldstart = "faas.coldstart"
        /// - SeeAlso: FaaSAttributes
        public static let invokedName = "faas.invoked_name"
        /// - SeeAlso: FaaSAttributes
        public static let invokedProvider = "faas.invoked_provider"
        /// - SeeAlso: FaaSAttributes
        public static let invokedRegion = "faas.invoked_region"

        /// - SeeAlso: FaaSAttributes.DocumentAttributes
        public enum Document {
            /// - SeeAlso: FaaSAttributes.DocumentAttributes
            public static let collection = "faas.document.collection"
            /// - SeeAlso: FaaSAttributes.DocumentAttributes
            public static let operation = "faas.document.operation"
            /// - SeeAlso: FaaSAttributes.DocumentAttributes
            public static let time = "faas.document.time"
            /// - SeeAlso: FaaSAttributes.DocumentAttributes
            public static let name = "faas.document.name"
        }
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic exception attributes.
    public var faas: FaaSAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Semantic conventions for reporting a single exception associated with a span  as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: FaaS attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/faas.md)
@dynamicMemberLookup
public struct FaaSAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    // MARK: - General

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// Type of the trigger on which the function is executed. See [OpenTelemetry: Function Trigger Type](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/faas.md#function-trigger-type) for possible values.
        public var trigger: Key<String> { .init(name: SpanAttributeName.FaaS.trigger) }

        /// The execution ID of the current function execution.
        public var execution: Key<String> { .init(name: SpanAttributeName.FaaS.execution) }

        /// A string containing the function invocation time in the
        /// [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html) format
        /// expressed in [UTC](https://www.w3.org/TR/NOTE-datetime).
        public var time: Key<String> { .init(name: SpanAttributeName.FaaS.time) }

        /// A string containing the schedule period as [Cron Expression](https://docs.oracle.com/cd/E12058_01/doc/doc.1014/e12030/cron_expressions.htm).
        public var cron: Key<String> { .init(name: SpanAttributeName.FaaS.cron) }

        /// A boolean that is true if the serverless function is executed for the first time (aka cold-start).
        public var coldstart: Key<Bool> { .init(name: SpanAttributeName.FaaS.coldstart) }

        /// The name of the invoked function.
        public var invokedName: Key<String> { .init(name: SpanAttributeName.FaaS.invokedName) }

        /// The cloud provider of the invoked function.
        /// See [OpenTelemetry: Outgoing Invocations](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/faas.md#outgoing-invocations) for possible values.
        public var invokedProvider: Key<String> { .init(name: SpanAttributeName.FaaS.invokedProvider) }

        /// The cloud region of the invoked function.
        public var invokedRegion: Key<String> { .init(name: SpanAttributeName.FaaS.invokedRegion) }
    }

    // MARK: - Document

    /// Semantic conventions for HTTP server spans.
    public var document: DocumentAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic Convention for FaaS triggered as a response to some data source operation such as a database or filesystem read/write.
    ///
    /// - SeeAlso: [OpenTelemetry: Datasource attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/faas.md#datasource)
    public struct DocumentAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The name of the source on which the triggering operation was performed.
            /// For example, in Cloud Storage or S3 corresponds to the bucket name, and in Cosmos DB to the database name.
            public var collection: Key<String> { .init(name: SpanAttributeName.FaaS.Document.collection) }

            /// Describes the type of the operation that was performed on the data. See [OpenTelemetry: Operation Type](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/faas.md#datasource) for possible values.
            public var operation: Key<String> { .init(name: SpanAttributeName.FaaS.Document.operation) }

            /// A string containing the time when the data was accessed in the
            /// [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html) format
            /// expressed in [UTC](https://www.w3.org/TR/NOTE-datetime).
            public var time: Key<String> { .init(name: SpanAttributeName.FaaS.Document.time) }

            /// The document name/table subjected to the operation. For example, in Cloud Storage or S3 is the name of the file,
            /// and in Cosmos DB the table name.
            public var name: Key<String> { .init(name: SpanAttributeName.FaaS.Document.name) }
        }
    }
}
#endif
