# ``Instrumentation``

Base set of types which can be used to instrument libraries, excluding tracing support. Instrument implementations can be used to extract or inject contextual metadata from carrier objects (such as http requests, messages, or similar), and can be used for context propagation across process boundaries, or enrichment of contextual data, such as injecting/extracting "authorized user" or similar metadata.

## Topics

### Instruments

- ``InstrumentationSystem``
- ``MultiplexInstrument``
- ``NoOpInstrument``
- ``Instrument``
- ``Extractor``
- ``Injector``
