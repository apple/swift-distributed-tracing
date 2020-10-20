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

import Baggage
import Foundation // string conversion for os_log seems to live here
import Instrumentation
import Tracing

#if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
import os.log
import os.signpost

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: OSSignpost Tracing

@available(OSX 10.14, *)
@available(iOS 10.0, *)
@available(tvOS 10.0, *)
@available(watchOS 3.0, *)
public struct OSSignpostTracingInstrument: Tracer {
    let log: OSLog
    let signpostName: StaticString

    public init(subsystem: String, category: String, signpostName: StaticString) {
        self.log = OSLog(subsystem: subsystem, category: category)
        self.signpostName = signpostName
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: Instrument API

    public func extract<Carrier, Extract>(
        _ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract
    ) {
        // noop; we could handle extracting our keys here
    }

    public func inject<Carrier, Inject>(
        _ baggage: Baggage, into carrier: inout Carrier, using injector: Inject
    ) {
        // noop; we could handle injecting our keys here
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: Tracing Instrument API

    public func startSpan(
        named operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime
    ) -> Span {
        OSSignpostSpan(
            log: self.log,
            named: operationName,
            signpostName: self.signpostName,
            baggage: baggage
            // , kind ignored
            // , time ignored, we capture it automatically
        )
    }

    public func forceFlush() {}
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: OSSignpost Span

@available(OSX 10.14, *)
@available(iOS 10.0, *)
@available(tvOS 10.0, *)
@available(watchOS 3.0, *)
final class OSSignpostSpan: Span {
    private let operationName: String
    public private(set) var baggage: Baggage

    private let log: OSLog
    private let signpostName: StaticString
    private var signpostID: OSSignpostID {
        self.baggage.signpostID! // guaranteed that we have "our" ID
    }

    // TODO: use os_unfair_lock
    let lock: NSLock

    public let isRecording: Bool

    private let startTime: DispatchWallTime
    private var endTime: DispatchWallTime?

    static let beginFormat: StaticString =
        """
        b;\
        id:%{public}ld;\
        parent-ids:%{public}s;\
        op-name:%{public}s
        """
    static let endFormat: StaticString =
        """
        e;
        """

    init(
        log: OSLog,
        named operationName: String,
        signpostName: StaticString,
        baggage: Baggage
    ) {
        self.log = log
        self.operationName = operationName
        self.signpostName = signpostName
        self.baggage = baggage

        self.startTime = .now() // meh
        self.isRecording = log.signpostsEnabled

        self.lock = NSLock()

        // // if the context we were started with already had a signpostID, it means we're should link with it
        // // TODO: is this right or we should rely on explicit link calls?
        // if context.signpostID != nil {
        //     self.addLink(SpanLink(context: context))
        // }

        // replace signpostID with "us" i.e. this span
        let signpostID = OSSignpostID(
            log: log,
            object: self
        )
        self.baggage.signpostID = signpostID

        if self.isRecording {
            os_signpost(
                .begin,
                log: self.log,
                name: self.signpostName,
                signpostID: self.signpostID,
                Self.beginFormat,
                self.signpostID.rawValue,
                "\(baggage.signpostTraceParentIDs.map { "\($0.rawValue)" }.joined(separator: ","))",
                operationName
            )
        }
    }

    #if DEBUG
    deinit {
        // sanity checking if we don't accidentally drop spans on the floor without ending them
        self.lock.lock() // TODO: somewhat bad idea, we should rather implement endTime as an atomic that's lockless to read (!)
        defer { self.lock.lock() }
        if self.endTime == nil {
            print("""
            warning: 
            Span \(self.signpostID) (\(self.operationName)) \
            [todo:source location] \
            was dropped without end() being called!
            """)
        }
    }
    #endif

    public func addLink(_ link: SpanLink) {
        guard self.isRecording else { return }
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let id = link.baggage.signpostID else {
            print(
                """
                Attempted to addLink(\(link)) to \(self.signpostID) (\(self.operationName))\
                but no `signpostID` present in passed in baggage context!
                """
            )
            return
        }

        self.baggage.signpostTraceParentIDs += [id]
    }

    func setStatus(_ status: SpanStatus) {}

    public func addEvent(_ event: SpanEvent) {
        guard self.isRecording else { return }

        // perhaps emit it as os_signpost(.event, ...)
    }

    func recordError(_ error: Error) {}

    public var attributes: SpanAttributes {
        get {
            [:] // ignore
        }
        set {
            // ignore
        }
    }

    public func end(at time: DispatchWallTime) {
        guard self.isRecording else { return }
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.endTime == nil else {
            print("warning: attempted to end() more-than-once the span: \(self.signpostID) (\(self.operationName))!")
            return
        }
        self.endTime = time

        os_signpost(
            .end,
            log: self.log,
            name: self.signpostName,
            signpostID: self.signpostID,
            Self.endFormat
        )
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Baggage Keys

@available(OSX 10.14, *)
@available(iOS 10.0, *)
@available(tvOS 10.0, *)
@available(watchOS 3.0, *)
enum OSSignpostTracingKeys {
    enum TraceParentIDs: Baggage.Key {
        typealias Value = [OSSignpostID]
    }

    enum SignpostID: Baggage.Key {
        typealias Value = OSSignpostID
    }
}

@available(OSX 10.14, *)
@available(iOS 10.0, *)
@available(tvOS 10.0, *)
@available(watchOS 3.0, *)
extension Baggage {
    var signpostTraceParentIDs: OSSignpostTracingKeys.TraceParentIDs.Value {
        get {
            self[OSSignpostTracingKeys.TraceParentIDs.self] ?? []
        }
        set {
            self[OSSignpostTracingKeys.TraceParentIDs.self] = newValue
        }
    }

    var signpostID: OSSignpostTracingKeys.SignpostID.Value? {
        get {
            self[OSSignpostTracingKeys.SignpostID.self]
        }
        set {
            self[OSSignpostTracingKeys.SignpostID.self] = newValue
        }
    }
}

#endif
