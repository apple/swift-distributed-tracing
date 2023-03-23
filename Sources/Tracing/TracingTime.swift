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

import CTracingTimeSupport
import Dispatch
@_exported import Instrumentation
@_exported import InstrumentationBaggage

// FIXME: mirrors DurationProtocol
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

// #if swift(>=5.7.0)
// @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
// public protocol SwiftDistributedTracingInstantProtocol: InstantProtocol {}
// #else
public protocol SwiftDistributedTracingInstantProtocol: Comparable, Hashable, Sendable {
    // associatedtype Duration: SwiftDistributedTracingDurationProtocol
}

// #endif

// #if swift(>=5.7.0)
// public protocol SwiftDistributedTracingClock: Clock {}
// #else
public protocol SwiftDistributedTracingClock: Sendable {}
// #endif

public protocol TracerInstantProtocol: SwiftDistributedTracingInstantProtocol {
    /// Representation of this instant as the number of milliseconds since UNIX Epoch (January 1st 1970)
    @inlinable
    var millisSinceEpoch: Int64 { get }
}

public protocol TracerClockProtocol: SwiftDistributedTracingClock {
    //  associatedtype Duration where Self.Duration == Self.Instant.Duration
    associatedtype Instant: TracerInstantProtocol

    static var now: Self.Instant { get }
    var now: Self.Instant { get }
}

extension TracerClock {
    // public typealias Duration = Swift.Duration
}

public struct TracerClock: TracerClockProtocol {
    // LIKE FOUNDATION
    internal typealias TimeInterval = Double

    public init() {
        // empty
    }

    public struct Instant: TracerInstantProtocol {
//    #if swift(>=5.7.0)
//    public typealias Duration = Swift.Duration
//    #endif

        public var millisSinceEpoch: Int64

        internal init(millisSinceEpoch: Int64) {
            self.millisSinceEpoch = millisSinceEpoch
        }

//    public func advanced(by duration: Self.Duration) -> Self {
//      var copy = self
//      copy.millisSinceEpoch += duration.milliseconds
//      return copy
//    }
//
//    public func duration(to other: Self) -> Self.Duration {
//      Duration.milliseconds(self.millisSinceEpoch - other.millisSinceEpoch)
//    }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.millisSinceEpoch < rhs.millisSinceEpoch
        }

        public static func == (lhs: Instant, rhs: Instant) -> Bool {
            lhs.millisSinceEpoch == rhs.millisSinceEpoch
        }

        public func hash(into hasher: inout Hasher) {
            self.millisSinceEpoch.hash(into: &hasher)
        }
    }

    public static var now: Self.Instant {
        TracerClock().now
    }

    /// The number of seconds from 1 January 1970 to the reference date, 1 January 2001.
    internal static let timeIntervalBetween1970AndReferenceDate: TimeInterval = 978_307_200.0

    /// The interval between 00:00:00 UTC on 1 January 2001 and the current date and time.
    internal static var timeIntervalSinceReferenceDate: TimeInterval {
        CTracingTimeSupport.SDTAbsoluteTimeGetCurrent()
    }

    public var now: Self.Instant {
        let sinceReference = TracerClock.timeIntervalSinceReferenceDate
        let between1970AndReference = TracerClock.timeIntervalBetween1970AndReferenceDate
        let nowDouble = sinceReference + between1970AndReference
        let nowMillis = Int64((nowDouble * 1000).rounded())

        return Instant(millisSinceEpoch: nowMillis)
    }

    //  #if swift(>=5.7.0)
    //  public var minimumResolution: Self.Duration {
//    .milliseconds(1)
    //  }
    //  #endif
}

// #if swift(>=5.7.0)
// @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
// extension TracerClock: Clock {
//
//  @available(*, deprecated, message: "TracerClock is not able to sleep()")
//  public func sleep(until deadline: Self.Instant, tolerance: Instant.Duration?) async throws {
//    fatalError("\(TracerClock.self) does not implement sleep() capabilities!")
//  }
//
// }
// #endif

extension DispatchWallTime {
    internal init(millisSinceEpoch: Int64) {
        let nanoSinceEpoch = UInt64(millisSinceEpoch) * 1_000_000
        let seconds = UInt64(nanoSinceEpoch / 1_000_000_000)
        let nanoseconds = nanoSinceEpoch - (seconds * 1_000_000_000)
        self.init(timespec: timespec(tv_sec: Int(seconds), tv_nsec: Int(nanoseconds)))
    }

    internal var millisSinceEpoch: Int64 {
        Int64(bitPattern: self.rawValue) / -1_000_000
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
