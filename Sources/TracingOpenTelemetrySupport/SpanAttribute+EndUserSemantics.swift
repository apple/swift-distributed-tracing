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
    /// - See: EndUserAttributes
    public enum EndUser {
        /// - See: EndUserAttributes
        public static let id = "enduser.id"
        /// - See: EndUserAttributes
        public static let role = "enduser.role"
        /// - See: EndUserAttributes
        public static let scope = "enduser.scope"
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic end-user attributes.
    public var endUser: EndUserAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// End-user-related semantic conventions as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: General identity attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/span-general.md#general-identity-attributes)
@dynamicMemberLookup
public struct EndUserAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// Username or client_id extracted from the access token or Authorization header in the inbound request from outside the system.
        public var id: Key<String> { .init(name: SpanAttributeName.EndUser.id) }

        /// Actual/assumed role the client is making the request under extracted from token or application security context.
        public var role: Key<String> { .init(name: SpanAttributeName.EndUser.role) }

        /// Scopes or granted authorities the client currently possesses extracted from token or application security context.
        /// The value would come from the scope associated with an OAuth 2.0 Access Token or an attribute value in a SAML 2.0 Assertion.
        public var scope: Key<String> { .init(name: SpanAttributeName.EndUser.scope) }
    }
}
#endif
