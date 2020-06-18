import SwiftBenchmarkTools

assert({
    print("===========================================================================")
    print("=          !!  YOU ARE RUNNING BENCHMARKS IN DEBUG MODE  !!               =")
    print("=     When running on the command line, use: `swift run -c release`       =")
    print("===========================================================================")
    return true
}())

@inline(__always)
private func registerBenchmark(_ bench: BenchmarkInfo) {
    registeredBenchmarks.append(bench)
}

@inline(__always)
private func registerBenchmark(_ benches: [BenchmarkInfo]) {
    benches.forEach(registerBenchmark)
}

@inline(__always)
private func registerBenchmark(_ name: String, _ function: @escaping (Int) -> Void, _ tags: [BenchmarkCategory]) {
    registerBenchmark(BenchmarkInfo(name: name, runFunction: function, tags: tags))
}

registerBenchmark(ExampleBenchmarks)

main()
