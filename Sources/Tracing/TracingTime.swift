//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(Linux)
import Glibc
#else
import Darwin
#endif

@_exported import Instrumentation
@_exported import InstrumentationBaggage

public protocol SwiftDistributedTracingDurationProtocol: Comparable, AdditiveArithmetic, Sendable {
    static func / (_ lhs: Self, _ rhs: Int) -> Self
    static func /= (_ lhs: inout Self, _ rhs: Int)
    static func * (_ lhs: Self, _ rhs: Int) -> Self
    static func *= (_ lhs: inout Self, _ rhs: Int)

    static func / (_ lhs: Self, _ rhs: Self) -> Double
}

extension SwiftDistributedTracingDurationProtocol {
    public static func /= (_ lhs: inout Self, _ rhs: Int) {
        lhs = lhs / rhs
    }
}

public protocol SwiftDistributedTracingInstantProtocol: Comparable, Hashable, Sendable {}

public protocol TracerInstantProtocol: SwiftDistributedTracingInstantProtocol {
    /// Representation of this instant as the number of milliseconds since UNIX Epoch (January 1st 1970)
    @inlinable
    var millisecondsSinceEpoch: UInt64 { get }
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
public protocol TracerClock {
    associatedtype Instant: TracerInstantProtocol

    var now: Self.Instant { get }
}

/// A basic "timestamp clock" implementation that is able to five the current time as an unix timestamp.
public struct DefaultTracerClock: TracerClock {
    public typealias Instant = Timestamp
    internal typealias TimeInterval = Double

    public init() {
        // empty
    }

    public struct Timestamp: TracerInstantProtocol {
        /// Milliseconds since January 1st, 1970, also known as "unix epoch".
        public var millisecondsSinceEpoch: UInt64

        internal init(millisecondsSinceEpoch: UInt64) {
            self.millisecondsSinceEpoch = millisecondsSinceEpoch
        }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.millisecondsSinceEpoch < rhs.millisecondsSinceEpoch
        }

        public static func == (lhs: Instant, rhs: Instant) -> Bool {
            lhs.millisecondsSinceEpoch == rhs.millisecondsSinceEpoch
        }

        public func hash(into hasher: inout Hasher) {
            self.millisecondsSinceEpoch.hash(into: &hasher)
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
        let nowMillis = UInt64(nowNanos / 1_000_000) // nanos to millis

        return Instant(millisecondsSinceEpoch: nowMillis)
    }
}

#if swift(>=5.7.0)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Duration {
    typealias Value = Int64

    var nanoseconds: Value {
        let (seconds, attoseconds) = self.components
        let sNanos = seconds * Value(1_000_000_000)
        let asNanos = attoseconds / Value(1_000_000_000)
        let (totalNanos, overflow) = sNanos.addingReportingOverflow(asNanos)
        return overflow ? .max : totalNanos
    }

    /// The microseconds representation of the `TimeAmount`.
    var microseconds: Value {
        self.nanoseconds / TimeUnit.microseconds.rawValue
    }

    /// The milliseconds representation of the `TimeAmount`.
    var milliseconds: Value {
        self.nanoseconds / TimeUnit.milliseconds.rawValue
    }

    /// The seconds representation of the `TimeAmount`.
    var seconds: Value {
        self.nanoseconds / TimeUnit.seconds.rawValue
    }

    var isEffectivelyInfinite: Bool {
        self.nanoseconds == .max
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Duration {
    private func chooseUnit(_ ns: Value) -> TimeUnit {
        if ns / TimeUnit.seconds.rawValue > 0 {
            return TimeUnit.seconds
        } else if ns / TimeUnit.milliseconds.rawValue > 0 {
            return TimeUnit.milliseconds
        } else if ns / TimeUnit.microseconds.rawValue > 0 {
            return TimeUnit.microseconds
        } else {
            return TimeUnit.nanoseconds
        }
    }

    /// Represents number of nanoseconds within given time unit
    enum TimeUnit: Value {
        case seconds = 1_000_000_000
        case milliseconds = 1_000_000
        case microseconds = 1000
        case nanoseconds = 1

        var abbreviated: String {
            switch self {
            case .nanoseconds: return "ns"
            case .microseconds: return "μs"
            case .milliseconds: return "ms"
            case .seconds: return "s"
            }
        }

        func duration(_ duration: Int) -> Duration {
            switch self {
            case .nanoseconds: return .nanoseconds(Value(duration))
            case .microseconds: return .microseconds(Value(duration))
            case .milliseconds: return .milliseconds(Value(duration))
            case .seconds: return .seconds(Value(duration))
            }
        }
    }
}
#endif
