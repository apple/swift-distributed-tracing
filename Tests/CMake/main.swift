//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import InMemoryTracing
import Instrumentation
import Tracing

let tracer = InMemoryTracer()
let span = tracer.startSpan("CMake")
span.end()
precondition(tracer.popFinishedSpans().count == 1)
let instrument = NoOpInstrument()
let noOpTracer = NoOpTracer()
noOpTracer.forceFlush()
_ = instrument
