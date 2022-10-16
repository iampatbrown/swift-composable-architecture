import ComposableArchitecture
import XCTest

extension DependencyValues {
  fileprivate var missingLiveDependency: Int {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }
}

private enum TestKey: TestDependencyKey {
  static let testValue = 42
}

var value = 0
func incrementedValue() -> Int {
  defer { value += 1 }
  return value
}

private struct Foo: TestDependencyKey {
  @Dependency(\.bar) var bar
  var value: Int

  static var testValue: Foo {
    Foo(value: incrementedValue())
  }
}

private struct Bar: TestDependencyKey {
  @Dependency(\.foo) var foo
  var value: Int

  static var testValue: Bar {
    Bar(value: incrementedValue())
  }
}

extension DependencyValues {
  fileprivate var foo: Foo {
    get { self[Foo.self] }
    set { self[Foo.self] = newValue }
  }

  fileprivate var bar: Bar {
    get { self[Bar.self] }
    set { self[Bar.self] = newValue }
  }
}

final class DependencyValuesTests: XCTestCase {
  func testMissingLiveValue() {
    #if DEBUG
      var line = 0
      XCTExpectFailure {
        var values = DependencyValues._current
        values.context = .live
        DependencyValues.$_current.withValue(values) {
          line = #line + 1
          @Dependency(\.missingLiveDependency) var missingLiveDependency: Int
          _ = missingLiveDependency
        }
      } issueMatcher: {
        $0.compactDescription == """
          "@Dependency(\\.missingLiveDependency)" has no live implementation, but was accessed \
          from a live context.

            Location:
              DependenciesTests/DependencyValuesTests.swift:\(line)
            Key:
              TestKey
            Value:
              Int

          Every dependency registered with the library must conform to "DependencyKey", and that \
          conformance must be visible to the running application.

          To fix, make sure that "TestKey" conforms to "DependencyKey" by providing a live \
          implementation of your dependency, and make sure that the conformance is linked with \
          this current application.
          """
      }
    #endif
  }

  func testWithValues() {
    let date = DependencyValues.withValues {
      $0.date = .constant(someDate)
    } operation: { () -> Date in
      @Dependency(\.date) var date
      return date.now
    }

    let defaultDate = DependencyValues.withValues {
      $0.context = .live
    } operation: { () -> Date in
      @Dependency(\.date) var date
      return date.now
    }

    XCTAssertEqual(date, someDate)
    XCTAssertNotEqual(defaultDate, someDate)
  }

  func testWithValue() {
    DependencyValues.withValue(\.context, .live) {
      let date = DependencyValues.withValue(\.date, .constant(someDate)) { () -> Date in
        @Dependency(\.date) var date
        return date.now
      }

      XCTAssertEqual(date, someDate)
      XCTAssertNotEqual(DependencyValues._current.date.now, someDate)
    }
  }

  func testDependencyDefaults() {
    struct Baz {
      @Dependency(\.foo) var foo
      @Dependency(\.bar) var bar
    }
    let baz = Baz()
    XCTAssertEqual(baz.foo.value, 0)
    XCTAssertEqual(baz.bar.value, 1)
    XCTAssertEqual(baz.foo.bar.value, 1)
    XCTAssertEqual(baz.bar.foo.value, 0)
  }
}

private let someDate = Date(timeIntervalSince1970: 1_234_567_890)
