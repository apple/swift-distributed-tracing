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

#if swift(>=5.6.0)
@_implementationOnly @preconcurrency import struct Dispatch.DispatchWallTime
#else
@_implementationOnly import struct Dispatch.DispatchWallTime
#endif

/// A wall-clock based time value used to mark the beginning and end of a trace ``Span``.
///
/// ### Rationale for this type
/// This type is introduced in order to abstract between various time sources, such as
/// Dispatch's `DispatchWallTime` or any potential future `Clock` type in the Swift
/// standard library (or elsewhere) that we might want to use as source of time.
///
/// Abstracting away the source of the measurement into this wrapper allows us to
/// have ``Tracer`` implementations don't care about the user API that is surfaced as `startSpan`
/// to end-users. As time goes on, this API may evolve, but we will not have to make breaking changes
/// to tracer implementations themselves.
public struct TracingTime: Sendable {
  enum Repr {
      case dispatchWallTime(DispatchWallTime)
  }
  private var repr: Repr

  private init(dispatchWallTime: DispatchWallTime) {
    self.repr = .dispatchWallTime(dispatchWallTime)
  }

  public static func now() -> TracingTime {
    .init(dispatchWallTime: .now())
  }

  public var rawValue: UInt64 {
    switch self.repr {
    case .dispatchWallTime(let wallTime):
      return wallTime.rawValue
    }
  }
}

extension TracingTime: Equatable {
  public static func ==(lhs: TracingTime, rhs: TracingTime) -> Bool {
    switch (lhs.repr, rhs.repr) {
    case (.dispatchWallTime(let l), .dispatchWallTime(let r)):
      return l.rawValue == r.rawValue
    }
  }

}

extension TracingTime: CustomStringConvertible {
  public var description: String {
    switch self.repr {
    case .dispatchWallTime(let wallTime):
      return "TracingTime(\(wallTime.rawValue))"
    }

  }
}