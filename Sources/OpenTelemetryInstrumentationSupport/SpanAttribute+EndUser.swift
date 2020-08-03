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
@dynamicMemberLookup
public struct EndUserAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// Username or client_id extracted from the access token or Authorization header in the inbound request from outside the system.
        public var id: SpanAttributeKey<String> { "enduser.id" }

        /// Actual/assumed role the client is making the request under extracted from token or application security context.
        public var role: SpanAttributeKey<String> { "enduser.role" }

        /// Scopes or granted authorities the client currently possesses extracted from token or application security context.
        /// The value would come from the scope associated with an OAuth 2.0 Access Token or an attribute value in a SAML 2.0 Assertion.
        public var scope: SpanAttributeKey<String> { "enduser.scope" }
    }
}
