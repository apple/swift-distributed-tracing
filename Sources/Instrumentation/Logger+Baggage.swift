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

import Logging
@_exported import InstrumentationBaggage

#if swift(>=5.5.0) && canImport(_Concurrency)
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Logger {

    /// Extract any potential ``Logger/Metadata`` that might be obtained by extracting the
    /// passed ``InstrumentationBaggage/Baggage`` to this logger's configured ``Logger/MetadataProvider``.
    ///
    /// Use this when it is necessary to "materialize" contextual baggage metadata into the logger, for future use,
    /// and you cannot rely on using the task-local way of passing Baggage around, e.g. when the logger will be
    /// used from multiple callbacks, and it would be troublesome to have to restore the task-local baggage in every callback.
    ///
    /// Generally prefer to set the task-local baggage using `Baggage.current` or `Tracer.withSpan`.
    public mutating func provideMetadata(from baggage: Baggage?) {
        guard let baggage = baggage else {
            return
        }

        Baggage.withValue(baggage) {
            let metadata = self.metadataProvider.provideMetadata()
            for (k, v) in metadata {
                self[metadataKey: k] = v
            }
        }
    }
}
#endif
