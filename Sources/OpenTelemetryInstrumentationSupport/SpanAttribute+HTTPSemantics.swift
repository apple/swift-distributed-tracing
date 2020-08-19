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
    public static let httpMethod = "http.method"
    public static let httpURL = "http.url"
    public static let httpTarget = "http.target"
    public static let httpHost = "http.host"
    public static let httpScheme = "http.scheme"
    public static let httpStatusCode = "http.status_code"
    public static let httpStatusText = "http.status_text"
    public static let httpFlavor = "http.flavor"
    public static let httpUserAgent = "http.user_agent"
    public static let httpRequestContentLength = "http.request_content_length"
    public static let httpRequestContentLengthUncompressed = "http.request_content_length_uncompressed"
    public static let httpResponseContentLength = "http.response_content_length"
    public static let httpResponseContentLengthUncompressed = "http.response_content_length_uncompressed"
    public static let httpServerName = "http.server_name"
    public static let httpServerRoute = "http.route"
    public static let httpServerClientIP = "http.client_ip"
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

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// HTTP request method. E.g. "GET".
        public var method: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpMethod) }

        /// Full HTTP request URL in the form scheme://host[:port]/path?query[#fragment].
        /// Usually the fragment is not transmitted over HTTP, but if it is known, it should be included nevertheless.
        public var url: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpURL) }

        /// The full request target as passed in a HTTP request line or equivalent, e.g. "/path/12314/?q=ddds#123".
        public var target: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpTarget) }

        /// The value of the HTTP host header. When the header is empty or not present, this attribute should be the same.
        public var host: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpHost) }

        /// The URI scheme identifying the used protocol: "http" or "https"
        public var scheme: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpScheme) }

        /// HTTP response status code. E.g. 200.
        public var statusCode: SpanAttributeKey<Int> { .init(name: SpanAttributeName.httpStatusCode) }

        /// HTTP reason phrase. E.g. "OK".
        public var statusText: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpStatusText) }

        /// Kind of HTTP protocol used: "1.0", "1.1", "2", "SPDY" or "QUIC".
        public var flavor: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpFlavor) }

        /// Value of the HTTP User-Agent header sent by the client.
        public var userAgent: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpUserAgent) }

        /// The size of the request payload body in bytes. This is the number of bytes transferred excluding headers and is often,
        /// but not always, present as the Content-Length header. For requests using transport encoding, this should be the
        /// compressed size.
        public var requestContentLength: SpanAttributeKey<Int> {
            .init(name: SpanAttributeName.httpRequestContentLength)
        }

        /// The size of the uncompressed request payload body after transport decoding. Not set if transport encoding not used.
        public var requestContentLengthUncompressed: SpanAttributeKey<Int> {
            .init(name: SpanAttributeName.httpRequestContentLengthUncompressed)
        }

        /// The size of the response payload body in bytes. This is the number of bytes transferred excluding headers and
        /// is often, but not always, present as the Content-Length header. For requests using transport encoding, this
        /// should be the compressed size.
        public var responseContentLength: SpanAttributeKey<Int> {
            .init(name: SpanAttributeName.httpResponseContentLength)
        }

        /// The size of the uncompressed response payload body after transport decoding. Not set if transport encoding not used.
        public var responseContentLengthUncompressed: SpanAttributeKey<Int> {
            .init(name: SpanAttributeName.httpResponseContentLengthUncompressed)
        }

        /// The primary server name of the matched virtual host. This should be obtained via configuration.
        /// If no such configuration can be obtained, this attribute MUST NOT be set (`net.hostName` should be used instead).
        public var serverName: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpServerName) }

        /// The matched route (path template). E.g. "/users/:userID?".
        public var serverRoute: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpServerRoute) }

        /// The IP address of the original client behind all proxies, if known (e.g. from X-Forwarded-For).
        /// Note that this is not necessarily the same as `net.peerIP`, which would identify the network-level peer,
        /// which may be a proxy.
        public var serverClientIP: SpanAttributeKey<String> { .init(name: SpanAttributeName.httpServerClientIP) }
    }
}
#endif
