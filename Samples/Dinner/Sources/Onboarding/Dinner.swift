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
// This source file is part of the Swift OpenTelemetry open source project
//
// Copyright (c) 2021 Moritz Lang and the Swift OpenTelemetry project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Tracing

func makeDinner() async throws -> Meal {
    try await InstrumentationSystem.tracer.withSpan("makeDinner") { _ in
        await sleep(for: .milliseconds(200))

        async let veggies = try chopVegetables()
        async let meat = marinateMeat()
        async let oven = preheatOven(temperature: 350)
        // ...
        return try await cook(veggies, meat, oven)
    }
}

func chopVegetables() async throws -> [Vegetable] {
    try await otelChopping1.tracer().withSpan("chopVegetables") { _ in
        // Chop the vegetables...!
        //
        // However, since chopping is a very difficult operation,
        // one chopping task can be performed at the same time on a single service!
        // (Imagine that... we cannot parallelize these two tasks, and need to involve another service).
        async let carrot = try chop(.carrot, tracer: otelChopping1.tracer())
        async let potato = try chop(.potato, tracer: otelChopping2.tracer())
        return try await [carrot, potato]
    }
}

func chop(_ vegetable: Vegetable, tracer: any Tracer) async throws -> Vegetable {
    await tracer.withSpan("chop-\(vegetable)") { _ in
        await sleep(for: .seconds(5))
        // ...
        return vegetable  // "chopped"
    }
}

func marinateMeat() async -> Meat {
    await sleep(for: .milliseconds(620))

    return await InstrumentationSystem.tracer.withSpan("marinateMeat") { _ in
        await sleep(for: .seconds(3))
        // ...
        return Meat()
    }
}

func preheatOven(temperature: Int) async -> Oven {
    await InstrumentationSystem.tracer.withSpan("preheatOven") { _ in
        // ...
        await sleep(for: .seconds(6))
        return Oven()
    }
}

func cook(_: Any, _: Any, _: Any) async -> Meal {
    await InstrumentationSystem.tracer.withSpan("cook") { span in
        span.addEvent("children-asking-if-done-already")
        await sleep(for: .seconds(3))
        span.addEvent("children-asking-if-done-already-again")
        await sleep(for: .seconds(2))
        // ...
        return Meal()
    }
}
