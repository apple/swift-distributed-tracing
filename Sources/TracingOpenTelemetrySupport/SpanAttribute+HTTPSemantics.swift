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
    /// - SeeAlso: HTTPAttributes
    public enum HTTP {
        /// - SeeAlso: HTTPAttributes
        public static let method = "http.method"
        /// - SeeAlso: HTTPAttributes
        public static let url = "http.url"
        /// - SeeAlso: HTTPAttributes
        public static let target = "http.target"
        /// - SeeAlso: HTTPAttributes
        public static let host = "http.host"
        /// - SeeAlso: HTTPAttributes
        public static let scheme = "http.scheme"
        /// - SeeAlso: HTTPAttributes
        public static let statusCode = "http.status_code"
        /// - SeeAlso: HTTPAttributes
        public static let flavor = "http.flavor"
        /// - SeeAlso: HTTPAttributes
        public static let userAgent = "http.user_agent"
        /// - SeeAlso: HTTPAttributes
        public static let requestContentLength = "http.request_content_length"
        /// - SeeAlso: HTTPAttributes
        public static let requestContentLengthUncompressed = "http.request_content_length_uncompressed"
        /// - SeeAlso: HTTPAttributes
        public static let responseContentLength = "http.response_content_length"
        /// - SeeAlso: HTTPAttributes
        public static let responseContentLengthUncompressed = "http.response_content_length_uncompressed"

        /// - SeeAlso: HTTPAttributes.ServerAttributes
        public enum Server {
            /// - SeeAlso: HTTPAttributes.ServerAttributes
            public static let name = "http.server_name"
            /// - SeeAlso: HTTPAttributes.ServerAttributes
            public static let route = "http.route"
            /// - SeeAlso: HTTPAttributes.ServerAttributes
            public static let clientIP = "http.client_ip"
        }
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
/// - SeeAlso: [OpenTelemetry: Semantic conventions for HTTP spans](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/http.md)
@dynamicMemberLookup
public struct HTTPAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    // MARK: - General

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// HTTP request method. E.g. "GET".
        public var method: Key<String> { .init(name: SpanAttributeName.HTTP.method) }

        /// Full HTTP request URL in the form scheme://host[:port]/path?query[#fragment].
        /// Usually the fragment is not transmitted over HTTP, but if it is known, it should be included nevertheless.
        public var url: Key<String> { .init(name: SpanAttributeName.HTTP.url) }

        /// The full request target as passed in a HTTP request line or equivalent, e.g. "/path/12314/?q=ddds#123".
        public var target: Key<String> { .init(name: SpanAttributeName.HTTP.target) }

        /// The value of the HTTP host header. When the header is empty or not present, this attribute should be the same.
        public var host: Key<String> { .init(name: SpanAttributeName.HTTP.host) }

        /// The URI scheme identifying the used protocol: "http" or "https"
        public var scheme: Key<String> { .init(name: SpanAttributeName.HTTP.scheme) }

        /// HTTP response status code. E.g. 200.
        public var statusCode: Key<Int> { .init(name: SpanAttributeName.HTTP.statusCode) }

        /// Kind of HTTP protocol used: "1.0", "1.1", "2", "SPDY" or "QUIC".
        ///
        /// - Note: If `net.transport` is not specified, it can be assumed to be `IP.TCP` except if `http.flavor`
        /// is `QUIC`, in which case `IP.UDP` is assumed.
        public var flavor: Key<String> { .init(name: SpanAttributeName.HTTP.flavor) }

        /// Value of the HTTP User-Agent header sent by the client.
        public var userAgent: Key<String> { .init(name: SpanAttributeName.HTTP.userAgent) }

        /// The size of the request payload body in bytes. This is the number of bytes transferred excluding headers and is often,
        /// but not always, present as the Content-Length header. For requests using transport encoding, this should be the
        /// compressed size.
        public var requestContentLength: Key<Int> {
            .init(name: SpanAttributeName.HTTP.requestContentLength)
        }

        /// The size of the uncompressed request payload body after transport decoding. Not set if transport encoding not used.
        public var requestContentLengthUncompressed: Key<Int> {
            .init(name: SpanAttributeName.HTTP.requestContentLengthUncompressed)
        }

        /// The size of the response payload body in bytes. This is the number of bytes transferred excluding headers and
        /// is often, but not always, present as the Content-Length header. For requests using transport encoding, this
        /// should be the compressed size.
        public var responseContentLength: Key<Int> {
            .init(name: SpanAttributeName.HTTP.responseContentLength)
        }

        /// The size of the uncompressed response payload body after transport decoding. Not set if transport encoding not used.
        public var responseContentLengthUncompressed: Key<Int> {
            .init(name: SpanAttributeName.HTTP.responseContentLengthUncompressed)
        }
    }

    // MARK: - Server

    /// Semantic conventions for HTTP server spans.
    public var server: ServerAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for HTTP Server spans as defined in the OpenTelemetry spec.
    ///
    /// - SeeAlso: [OpenTelemetry: Semantic conventions for HTTP Server spans](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/http.md#http-server)
    public struct ServerAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The primary server name of the matched virtual host. This should be obtained via configuration.
            /// If no such configuration can be obtained, this attribute MUST NOT be set (`net.hostName` should be used instead).
            public var name: Key<String> { .init(name: SpanAttributeName.HTTP.Server.name) }

            /// The matched route (path template). E.g. "/users/:userID?".
            public var route: Key<String> { .init(name: SpanAttributeName.HTTP.Server.route) }

            /// The IP address of the original client behind all proxies, if known (e.g. from [X-Forwarded-For](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For)).
            ///
            /// - Note: This is not necessarily the same as `net.peer.ip`, which would identify the network-level peer, which may be a proxy.
            public var clientIP: Key<String> { .init(name: SpanAttributeName.HTTP.Server.clientIP) }
        }
    }
}
#endif
