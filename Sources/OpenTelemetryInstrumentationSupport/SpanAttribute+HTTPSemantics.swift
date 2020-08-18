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

#if swift(>=5.2)
import TracingInstrumentation

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
@dynamicMemberLookup
public struct HTTPAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// HTTP request method. E.g. "GET".
        public var method: SpanAttributeKey<String> { "http.method" }

        /// Full HTTP request URL in the form scheme://host[:port]/path?query[#fragment].
        /// Usually the fragment is not transmitted over HTTP, but if it is known, it should be included nevertheless.
        public var url: SpanAttributeKey<String> { "http.url" }

        /// The full request target as passed in a HTTP request line or equivalent, e.g. "/path/12314/?q=ddds#123".
        public var target: SpanAttributeKey<String> { "http.target" }

        /// The value of the HTTP host header. When the header is empty or not present, this attribute should be the same.
        public var host: SpanAttributeKey<String> { "http.host" }

        /// The URI scheme identifying the used protocol: "http" or "https"
        public var scheme: SpanAttributeKey<String> { "http.scheme" }

        /// HTTP response status code. E.g. 200.
        public var statusCode: SpanAttributeKey<Int> { "http.status_code" }

        /// HTTP reason phrase. E.g. "OK".
        public var statusText: SpanAttributeKey<String> { "http.status_text" }

        /// Kind of HTTP protocol used: "1.0", "1.1", "2", "SPDY" or "QUIC".
        public var flavor: SpanAttributeKey<String> { "http.flavor" }

        /// Value of the HTTP User-Agent header sent by the client.
        public var userAgent: SpanAttributeKey<String> { "http.user_agent" }

        /// The size of the request payload body in bytes. This is the number of bytes transferred excluding headers and is often,
        /// but not always, present as the Content-Length header. For requests using transport encoding, this should be the
        /// compressed size.
        public var requestContentLength: SpanAttributeKey<Int> { "http.request_content_length" }

        /// The size of the uncompressed request payload body after transport decoding. Not set if transport encoding not used.
        public var requestContentLengthUncompressed: SpanAttributeKey<Int> {
            "http.request_content_length_uncompressed"
        }

        /// The size of the response payload body in bytes. This is the number of bytes transferred excluding headers and
        /// is often, but not always, present as the Content-Length header. For requests using transport encoding, this
        /// should be the compressed size.
        public var responseContentLength: SpanAttributeKey<Int> { "http.response_content_length" }

        /// The size of the uncompressed response payload body after transport decoding. Not set if transport encoding not used.
        public var responseContentLengthUncompressed: SpanAttributeKey<Int> {
            "http.response_content_length_uncompressed"
        }

        /// The primary server name of the matched virtual host. This should be obtained via configuration.
        /// If no such configuration can be obtained, this attribute MUST NOT be set (`net.hostName` should be used instead).
        public var serverName: SpanAttributeKey<String> { "http.server_name" }

        /// The matched route (path template). E.g. "/users/:userID?".
        public var serverRoute: SpanAttributeKey<String> { "http.route" }

        /// The IP address of the original client behind all proxies, if known (e.g. from X-Forwarded-For).
        /// Note that this is not necessarily the same as `net.peerIP`, which would identify the network-level peer,
        /// which may be a proxy.
        public var serverClientIP: SpanAttributeKey<String> { "http.client_ip" }
    }
}
#endif
