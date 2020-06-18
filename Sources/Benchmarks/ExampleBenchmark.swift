import SwiftBenchmarkTools

public let ExampleBenchmarks: [BenchmarkInfo] = [
    BenchmarkInfo(
        name: "ExampleBenchmarks.bench_example",
        runFunction: { _ in try! bench_example(50000) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),
]

private func setUp() {
    // ...
}

private func tearDown() {
    // ...
}

// completely silly "benchmark" function
func bench_example(_ count: Int) throws {
    var sum = 0
    for i in 1...count {
        sum += 1
    }
}
