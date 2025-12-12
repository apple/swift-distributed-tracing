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
#elseif os(Windows)
import WinSDK
#else
#error("Unsupported runtime")
#endif

#if os(WASI)
import _CWASI
#endif

/// A type that represents a point in time down to the nanosecond.
public protocol TracerInstant: Comparable, Hashable, Sendable {
    /// The representation of this instant as the number of nanoseconds since UNIX Epoch (January 1st 1970).
    var nanosecondsSinceEpoch: UInt64 { get }
}

extension TracerInstant {
    /// The representation of this instant as the number of milliseconds since UNIX Epoch (January 1st 1970).
    @inlinable
    public var millisecondsSinceEpoch: UInt64 {
        self.nanosecondsSinceEpoch / 1_000_000
    }
}

/// A specialized clock protocol for purposes of tracing.
///
/// A tracer clock must ONLY be able to offer the current time in the form of an unix timestamp.
/// It does not have to allow sleeping, nor is it interchangeable with other notions of clocks (such as monotonic time).
///
/// If the standard library, or foundation, or someone else were to implement an UTCClock or UNIXTimestampClock,
/// they can be made to conform to `TracerClock`.
///
/// The primary purpose of this clock protocol is to enable mocking the "now" time when starting and ending spans,
/// especially when the system is already using some notion of simulated or mocked time, such that traces are
/// expressed using the same notion of time.
public struct DefaultTracerClock {
    /// The type that represents the a time instant.
    public typealias Instant = Timestamp

    /// Create a default tracer clock
    public init() {
        // empty
    }

    /// An instant point in time
    public struct Timestamp: TracerInstant {
        /// The representation of this instant as the number of nanoseconds since UNIX Epoch (January 1st 1970).
        public let nanosecondsSinceEpoch: UInt64

        /// Creates a new point in time.
        /// - Parameter nanosecondsSinceEpoch: the number of nanoseconds since UNIX Epoch (January 1st 1970).
        public init(nanosecondsSinceEpoch: UInt64) {
            self.nanosecondsSinceEpoch = nanosecondsSinceEpoch
        }

        /// A Boolean value that indicates the first timestamp is less than the second.
        /// - Parameters:
        ///   - lhs: The first time stamp.
        ///   - rhs: The second time stamp
        /// - Returns: `true` if the first time stamp is less than the second; otherwise `false`.
        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
        }

        /// A Boolean value that indicates whether the time stamps are equivalent.
        /// - Parameters:
        ///   - lhs: The first time stamp.
        ///   - rhs: The second time stamp
        /// - Returns: `true` if the time stamps are equivalent; otherwise `false`.
        public static func == (lhs: Instant, rhs: Instant) -> Bool {
            lhs.nanosecondsSinceEpoch == rhs.nanosecondsSinceEpoch
        }

        /// Hashes the essential components of this value by feeding them into the given hasher.
        /// - Parameter hasher: The hasher to use when combining the components of this instance.
        public func hash(into hasher: inout Hasher) {
            self.nanosecondsSinceEpoch.hash(into: &hasher)
        }
    }

    /// The current instant in time.
    public static var now: Self.Instant {
        DefaultTracerClock().now
    }

    /// Returns the current instant in time.
    public var now: Self.Instant {
        #if os(Windows)
        var fileTime = FILETIME()
        GetSystemTimePreciseAsFileTime(&fileTime)

        let fileTime64 = (UInt64(fileTime.dwHighDateTime) << 32) | UInt64(fileTime.dwLowDateTime)

        let windowsToUnixEpochIn100ns: UInt64 = 116_444_736_000_000_000
        let unixTime100ns = fileTime64 &- windowsToUnixEpochIn100ns
        let nowNanos = unixTime100ns &* 100

        return Instant(nanosecondsSinceEpoch: nowNanos)
        #else  // not Windows
        var ts = timespec()
        #if os(WASI)
        CWASI_clock_gettime_realtime(&ts)
        #else
        clock_gettime(CLOCK_REALTIME, &ts)
        #endif
        /// We use unsafe arithmetic here because `UInt64.max` nanoseconds is more than 580 years,
        /// and the odds that this code will still be running 530 years from now is very, very low,
        /// so as a practical matter this will never overflow.
        let nowNanos = UInt64(ts.tv_sec) &* 1_000_000_000 &+ UInt64(ts.tv_nsec)

        return Instant(nanosecondsSinceEpoch: nowNanos)
        #endif  // Windows
    }
}
