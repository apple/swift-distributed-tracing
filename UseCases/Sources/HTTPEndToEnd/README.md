#  HTTP End-to-end

This use-case demonstrates how both `BaggageContext` and `Instrument` may work in an end-to-end scenario. The example 
defines two services: 

- 🧾 `OrderService`
- 📦 `StorageService`

`BaggageLogging` is used throught the example to automatically add the `BaggageContext` contents to the `Logger` being used. 

## Steps

1. `AsyncHTTPClient` used to make a request to the order service
2. On receive, order service uses `FakeTracer` to extract trace information into the `BaggageContext`
3. Because no trace ID exists at that point, `FakeTracer` will generate a new one to be stored in the `BaggageContext`
4. The order service makes an HTTP request to the storage service (using `InstrumentedHTTPClient`)
5. `InstrumentedHTTPClient` uses `FakeTracer` to automatically inject the trace ID into the request headers
6. On receive, storage service uses `FakeTracer` to extract trace information into the `BaggageContext` 
