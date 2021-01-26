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
    /// - See: ExceptionAttributes
    public enum Exception {
        /// - See: ExceptionAttributes
        public static let type = "exception.type"
        /// - See: ExceptionAttributes
        public static let message = "exception.message"
        /// - See: ExceptionAttributes
        public static let stacktrace = "exception.stacktrace"
        /// - See: ExceptionAttributes
        public static let escaped = "exception.escaped"
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic exception attributes.
    public var exception: ExceptionAttributes {
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
/// - SeeAlso: [OpenTelemetry: Exception attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/exceptions.md)
@dynamicMemberLookup
public struct ExceptionAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// The type of the exception (its fully-qualified class name, if applicable). The dynamic type of the exception should
        /// be preferred over the static type in languages that support it.
        public var type: Key<String> { .init(name: SpanAttributeName.Exception.type) }

        /// The exception message.
        public var message: Key<String> { .init(name: SpanAttributeName.Exception.message) }

        /// A stacktrace as a string in the natural representation for the language runtime. The representation is to be determined
        /// and documented by each language SIG.
        public var stacktrace: Key<String> { .init(name: SpanAttributeName.Exception.stacktrace) }

        /// SHOULD be set to true if the exception event is recorded at a point where it is known that the exception
        /// is escaping the scope of the span.
        public var escaped: Key<Bool> { .init(name: SpanAttributeName.Exception.escaped) }
    }
}
#endif
