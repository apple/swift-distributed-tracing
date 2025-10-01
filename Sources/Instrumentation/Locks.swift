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

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(WASILibc)
// No locking on WASILibc
#elseif canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Musl)
import Musl
#else
#error("Unsupported runtime")
#endif

/// A reader/writer threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_rwlock_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
public final class ReadWriteLock: @unchecked Sendable {
    #if canImport(WASILibc)
    // WASILibc is single threaded, provides no locks
    #elseif os(Windows)
    fileprivate let rwlock: UnsafeMutablePointer<SRWLOCK> =
        UnsafeMutablePointer.allocate(capacity: 1)
    fileprivate var shared: Bool = true
    #else
    fileprivate let rwlock: UnsafeMutablePointer<pthread_rwlock_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
    #endif

    /// Create a new lock.
    public init() {
        #if canImport(WASILibc)
        // WASILibc is single threaded, provides no locks
        #elseif os(Windows)
        InitializeSRWLock(self.rwlock)
        #else
        let err = pthread_rwlock_init(self.rwlock, nil)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }

    deinit {
        #if canImport(WASILibc)
        // WASILibc is single threaded, provides no locks
        #elseif os(Windows)
        // SRWLOCK does not need to be free'd
        self.rwlock.deallocate()
        #else
        let err = pthread_rwlock_destroy(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        self.rwlock.deallocate()
        #endif
    }

    /// Acquire a reader lock.
    ///
    /// Whenever possible, consider using `withReaderLock` instead of this
    /// method and `unlock`, to simplify lock handling.
    public func lockRead() {
        #if canImport(WASILibc)
        // WASILibc is single threaded, provides no locks
        #elseif os(Windows)
        AcquireSRWLockShared(self.rwlock)
        self.shared = true
        #else
        let err = pthread_rwlock_rdlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }

    /// Acquire a writer lock.
    ///
    /// Whenever possible, consider using `withWriterLock` instead of this
    /// method and `unlock`, to simplify lock handling.
    public func lockWrite() {
        #if canImport(WASILibc)
        // WASILibc is single threaded, provides no locks
        #elseif os(Windows)
        AcquireSRWLockExclusive(self.rwlock)
        self.shared = false
        #else
        let err = pthread_rwlock_wrlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withReaderLock` and `withWriterLock`
    /// instead of this method and `lockRead` and `lockWrite`, to simplify lock
    /// handling.
    public func unlock() {
        #if canImport(WASILibc)
        // WASILibc is single threaded, provides no locks
        #elseif os(Windows)
        if self.shared {
            ReleaseSRWLockShared(self.rwlock)
        } else {
            ReleaseSRWLockExclusive(self.rwlock)
        }
        #else
        let err = pthread_rwlock_unlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }
}

extension ReadWriteLock {
    /// Acquire the reader lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lockRead` and `unlock`
    /// in most situations, as it ensures that the lock will be released
    /// regardless of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the reader lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withReaderLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockRead()
        defer {
            self.unlock()
        }
        return try body()
    }

    /// Acquire the writer lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lockWrite` and `unlock`
    /// in most situations, as it ensures that the lock will be released
    /// regardless of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the writer lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockWrite()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withReaderLockVoid(_ body: () throws -> Void) rethrows {
        try self.withReaderLock(body)
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withWriterLockVoid(_ body: () throws -> Void) rethrows {
        try self.withWriterLock(body)
    }
}

/// A wrapper providing locked access to a value.
///
/// Marked as @unchecked Sendable due to the synchronization being
/// performed manually using locks.
@_spi(Locking)  // Use the `package` access modifier once min Swift version is increased.
public final class LockedValueBox<Value: Sendable>: @unchecked Sendable {
    private let lock = ReadWriteLock()
    private var value: Value
    public init(_ value: Value) {
        self.value = value
    }

    public func withValue<R>(_ work: (inout Value) throws -> R) rethrows -> R {
        try self.lock.withWriterLock {
            try work(&self.value)
        }
    }
}
