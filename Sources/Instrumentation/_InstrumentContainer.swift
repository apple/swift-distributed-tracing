//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Internal hook for instrument types that contain other instruments and need to participate in
/// `firstInstrument(where:)` discovery walks. Conformers expose their members so the recursion in
/// ``MultiplexInstrument`` and ``InstrumentationSystem/_findInstrument(where:)`` can reach conformers
/// nested at any depth.
///
/// Implementation detail of the discovery chain — not a stable API.
internal protocol _InstrumentContainer {
    /// Walks the container looking for the first member satisfying `predicate`, recursing into nested
    /// ``_InstrumentContainer`` members.
    func firstInstrument(where predicate: (Instrument) -> Bool) -> Instrument?
}
