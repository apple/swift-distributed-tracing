//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#pragma once

#if __wasi__

#include <fcntl.h>
#include <time.h>

static inline void CWASI_clock_gettime_realtime(struct timespec *tv) {
    // ClangImporter doesn't support `CLOCK_REALTIME` declaration in WASILibc, thus we have to define a bridge manually
    clock_gettime(CLOCK_REALTIME, tv);
}

#endif // __wasi__
