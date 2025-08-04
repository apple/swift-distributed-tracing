# ``TracingMacros``

Macro helpers for Tracing.

## Overview

The TracingMacros module provides optional macros to make it easier to write traced code.

The ``Traced(_:context:ofKind:span:)`` macro lets you avoid the extra indentation that comes with
adopting traced code, and avoids having to keep the throws/try and async/await
in-sync with the body. You can just attach `@Traced` to a function and get
started.

## Topics

### Tracing functions
- ``Traced(_:context:ofKind:span:)``
- ``TracedOperationName``

