# ``TracingMacros/TracedOperationName``

### Examples

The default behavior is to use the base name of the function, but you can
explicitly specify this as well. This creates a span named `"preheatOven"`:
```swift
@Traced(.baseName)
func preheatOven(temperature: Int)
```

You can request the full name of the function as the span name, this
creates a span named `"preheatOven(temperature:)"`:
```swift
@Traced(.fullName)
func preheatOven(temperature: Int)
```

And it is also initializable with a string literal for fully custom names,
this creates a span explicitly named `"preheat oven"`:
```swift
@Traced("preheat oven")
func preheatOven(temperature: Int)
```
And if you need to load an existing string value as a name, you can use
`.string(someString)` to adapt it.


## Topics

### Create Operation Names
- ``baseName``
- ``fullName``
- ``string(_:)``
- ``init(stringLiteral:)``

### Convert an Operation Name to a String
- ``operationName(baseName:fullName:)``
