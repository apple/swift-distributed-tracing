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
    /// - See: HTTPAttributes
    public enum HTTP {
        /// - See: HTTPAttributes
        public static let method = "http.method"
        /// - See: HTTPAttributes
        public static let url = "http.url"
        /// - See: HTTPAttributes
        public static let target = "http.target"
        /// - See: HTTPAttributes
        public static let host = "http.host"
        /// - See: HTTPAttributes
        public static let scheme = "http.scheme"
        /// - See: HTTPAttributes
        public static let statusCode = "http.status_code"
        /// - See: HTTPAttributes
        public static let statusText = "http.status_text"
        /// - See: HTTPAttributes
        public static let flavor = "http.flavor"
        /// - See: HTTPAttributes
        public static let userAgent = "http.user_agent"
        /// - See: HTTPAttributes
        public static let requestContentLength = "http.request_content_length"
        /// - See: HTTPAttributes
        public static let requestContentLengthUncompressed = "http.request_content_length_uncompressed"
        /// - See: HTTPAttributes
        public static let responseContentLength = "http.response_content_length"
        /// - See: HTTPAttributes
        public static let responseContentLengthUncompressed = "http.response_content_length_uncompressed"
        /// - See: HTTPAttributes
        public static let serverName = "http.server_name"
        /// - See: HTTPAttributes
        public static let serverRoute = "http.route"
        /// - See: HTTPAttributes
        public static let serverClientIP = "http.client_ip"
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic conventions for HTTP spans.
    public var http: HTTPAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Semantic conventions for HTTP spans as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: Semantic conventions for HTTP spans](https://github.com/open-telemetry/opentelemetry-specification/blob/b70565d5a8a13d26c91fb692879dc874d22c3ac8/specification/trace/semantic_conventions/http.md) (as of August 2020)
@dynamicMemberLookup
public struct HTTPAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// HTTP request method. E.g. "GET".
        public var method: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.method) }

        /// Full HTTP request URL in the form scheme://host[:port]/path?query[#fragment].
        /// Usually the fragment is not transmitted over HTTP, but if it is known, it should be included nevertheless.
        public var url: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.url) }

        /// The full request target as passed in a HTTP request line or equivalent, e.g. "/path/12314/?q=ddds#123".
        public var target: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.target) }

        /// The value of the HTTP host header. When the header is empty or not present, this attribute should be the same.
        public var host: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.host) }

        /// The URI scheme identifying the used protocol: "http" or "https"
        public var scheme: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.scheme) }

        /// HTTP response status code. E.g. 200.
        public var statusCode: SpanAttribute.Key<Int> { .init(name: SpanAttributeName.HTTP.statusCode) }

        /// HTTP reason phrase. E.g. "OK".
        public var statusText: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.statusText) }

        /// Kind of HTTP protocol used: "1.0", "1.1", "2", "SPDY" or "QUIC".
        public var flavor: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.flavor) }

        /// Value of the HTTP User-Agent header sent by the client.
        public var userAgent: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.userAgent) }

        /// The size of the request payload body in bytes. This is the number of bytes transferred excluding headers and is often,
        /// but not always, present as the Content-Length header. For requests using transport encoding, this should be the
        /// compressed size.
        public var requestContentLength: SpanAttribute.Key<Int> {
            .init(name: SpanAttributeName.HTTP.requestContentLength)
        }

        /// The size of the uncompressed request payload body after transport decoding. Not set if transport encoding not used.
        public var requestContentLengthUncompressed: SpanAttribute.Key<Int> {
            .init(name: SpanAttributeName.HTTP.requestContentLengthUncompressed)
        }

        /// The size of the response payload body in bytes. This is the number of bytes transferred excluding headers and
        /// is often, but not always, present as the Content-Length header. For requests using transport encoding, this
        /// should be the compressed size.
        public var responseContentLength: SpanAttribute.Key<Int> {
            .init(name: SpanAttributeName.HTTP.responseContentLength)
        }

        /// The size of the uncompressed response payload body after transport decoding. Not set if transport encoding not used.
        public var responseContentLengthUncompressed: SpanAttribute.Key<Int> {
            .init(name: SpanAttributeName.HTTP.responseContentLengthUncompressed)
        }

        /// The primary server name of the matched virtual host. This should be obtained via configuration.
        /// If no such configuration can be obtained, this attribute MUST NOT be set (`net.hostName` should be used instead).
        public var serverName: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.serverName) }

        /// The matched route (path template). E.g. "/users/:userID?".
        public var serverRoute: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.serverRoute) }

        /// The IP address of the original client behind all proxies, if known (e.g. from X-Forwarded-For).
        /// Note that this is not necessarily the same as `net.peerIP`, which would identify the network-level peer,
        /// which may be a proxy.
        public var serverClientIP: SpanAttribute.Key<String> { .init(name: SpanAttributeName.HTTP.serverClientIP) }
    }
}
#endif
