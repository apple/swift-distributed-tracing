//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2022 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@available(macOS 13.0, iOS 15.0, *)
public struct TracingClock: _Concurrency.Clock {
    public typealias Duration = Swift.Duration
    public struct Instant: InstantProtocol {
        public typealias Duration = TracingClock.Duration
        public var raw: UInt64

        public func advanced(by duration: TracingClock.Duration) -> TracingClock.Instant {
            var copy = self
            // FIXME: implement this...
            return copy
        }

        public func duration(to other: TracingClock.Instant) -> TracingClock.Duration {
            return .milliseconds(self.raw - other.raw)
        }


        public static func <(lhs: TracingClock.Instant, rhs: TracingClock.Instant) -> Bool {
            lhs.raw < rhs.raw
        }
    }

    public var now: Instant {
        .init(raw: 0) // TODO: implement "now"
    }
    public var minimumResolution: Duration {
        .milliseconds(1)
    }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        fatalError("Not implemented for TracingClock")
    }
}

