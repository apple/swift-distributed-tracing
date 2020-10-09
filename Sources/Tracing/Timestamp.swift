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

import Dispatch

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

/// Represents a wall-clock time with microsecond precision.
public struct Timestamp: Comparable, CustomStringConvertible {
    private let time: DispatchWallTime

    /// Microseconds since Epoch
    public var microsSinceEpoch: Int64 {
        return Int64(bitPattern: self.time.rawValue) / -1000
    }

    /// Milliseconds since Epoch
    public var millisSinceEpoch: Int64 {
        return Int64(bitPattern: self.time.rawValue) / -1_000_000
    }

    /// Returns the current time.
    public static func now() -> Timestamp {
        return self.init(time: .now())
    }

    /// A time in the distant future.
    public static let distantFuture: Timestamp = .init(time: .distantFuture)

    public init(millisSinceEpoch: Int64) {
        let nanoSinceEpoch = UInt64(millisSinceEpoch) * 1_000_000
        let seconds = UInt64(nanoSinceEpoch / 1_000_000_000)
        let nanoseconds = nanoSinceEpoch - (seconds * 1_000_000_000)
        self.init(time: DispatchWallTime(timespec: timespec(tv_sec: Int(seconds), tv_nsec: Int(nanoseconds))))
    }

    public init(time: DispatchWallTime) {
        self.time = time
    }

    public var description: String {
        return "Timestamp(\(self.time.rawValue))"
    }

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.time < rhs.time
    }

    public static func == (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.time == rhs.time
    }
}
