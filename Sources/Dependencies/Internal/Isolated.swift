// Copyright © 2022 Home Delivery Service. See LICENSE file.

import Foundation

@propertyWrapper
final class Isolated<Value>: @unchecked Sendable {
    private var _wrappedValue: Value
    private let lock = NSRecursiveLock()

    public init(wrappedValue: Value) {
        _wrappedValue = wrappedValue
    }

    public var wrappedValue: Value {
        _read {
            self.lock.lock()
            defer { self.lock.unlock() }
            yield self._wrappedValue
        }
        _modify {
            self.lock.lock()
            defer { self.lock.unlock() }
            yield &self._wrappedValue
        }
    }
}
