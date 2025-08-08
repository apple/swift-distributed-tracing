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
#if canImport(wasi_pthread)
import wasi_pthread
#endif
#else
#error("Unsupported runtime")
#endif

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO.
@_spi(Locking)  // Use the `package` access modifier once min Swift version is increased.
public final class ReadWriteLock {
    private let rwlock: UnsafeMutablePointer<pthread_rwlock_t> = UnsafeMutablePointer.allocate(capacity: 1)

    /// Create a new lock.
    public init() {
        let err = pthread_rwlock_init(self.rwlock, nil)
        precondition(err == 0, "pthread_rwlock_init failed with error \(err)")
    }

    deinit {
        let err = pthread_rwlock_destroy(self.rwlock)
        precondition(err == 0, "pthread_rwlock_destroy failed with error \(err)")
        self.rwlock.deallocate()
    }

    /// Acquire a reader lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lockRead() {
        let err = pthread_rwlock_rdlock(self.rwlock)
        precondition(err == 0, "pthread_rwlock_rdlock failed with error \(err)")
    }

    /// Acquire a writer lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lockWrite() {
        let err = pthread_rwlock_wrlock(self.rwlock)
        precondition(err == 0, "pthread_rwlock_wrlock failed with error \(err)")
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    public func unlock() {
        let err = pthread_rwlock_unlock(self.rwlock)
        precondition(err == 0, "pthread_rwlock_unlock failed with error \(err)")
    }
}

extension ReadWriteLock {
    /// Acquire the reader lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
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
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockWrite()
        defer {
            self.unlock()
        }
        return try body()
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
