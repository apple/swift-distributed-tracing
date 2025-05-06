//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import Instrumentation
@_exported import ServiceContextModule

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

#if canImport(_CWASI)
import _CWASI
#endif

public protocol TracerInstant: Comparable, Hashable, Sendable {
    /// Representation of this instant as the number of nanoseconds since UNIX Epoch (January 1st 1970)
    var nanosecondsSinceEpoch: UInt64 { get }
}

extension TracerInstant {
    /// Representation of this instant as the number of milliseconds since UNIX Epoch (January 1st 1970)
    @inlinable
    public var millisecondsSinceEpoch: UInt64 {
        self.nanosecondsSinceEpoch / 1_000_000
    }
}

/// A specialized clock protocol for purposes of tracing.
///
/// A tracer clock must ONLY be able to offer the current time in the form of an unix timestamp.
/// It does not have to allow sleeping, nor is it interchangeable with other notions of clocks (e.g. such as monotonic time etc).
///
/// If the standard library, or foundation, or someone else were to implement an UTCClock or UNIXTimestampClock,
/// they can be made to conform to `TracerClock`.
///
/// The primary purpose of this clock protocol is to enable mocking the "now" time when starting and ending spans,
/// especially when the system is already using some notion of simulated or mocked time, such that traces are
/// expressed using the same notion of time.
public struct DefaultTracerClock {
    public typealias Instant = Timestamp

    public init() {
        // empty
    }

    public struct Timestamp: TracerInstant {
        public let nanosecondsSinceEpoch: UInt64

        public init(nanosecondsSinceEpoch: UInt64) {
            self.nanosecondsSinceEpoch = nanosecondsSinceEpoch
        }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
        }

        public static func == (lhs: Instant, rhs: Instant) -> Bool {
            lhs.nanosecondsSinceEpoch == rhs.nanosecondsSinceEpoch
        }

        public func hash(into hasher: inout Hasher) {
            self.nanosecondsSinceEpoch.hash(into: &hasher)
        }
    }

    public static var now: Self.Instant {
        DefaultTracerClock().now
    }

    public var now: Self.Instant {
        var ts = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        /// We use unsafe arithmetic here because `UInt64.max` nanoseconds is more than 580 years,
        /// and the odds that this code will still be running 530 years from now is very, very low,
        /// so as a practical matter this will never overflow.
        let nowNanos = UInt64(ts.tv_sec) &* 1_000_000_000 &+ UInt64(ts.tv_nsec)

        return Instant(nanosecondsSinceEpoch: nowNanos)
    }
}
