import Foundation

extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {
  @inlinable @discardableResult
  func sync<R>(_ work: () -> R) -> R {
    os_unfair_lock_lock(self)
    defer { os_unfair_lock_unlock(self) }
    return work()
  }

  @inlinable
  func lock() {
    os_unfair_lock_lock(self)
  }

  @inlinable
  func unlock() {
    os_unfair_lock_unlock(self)
  }
}

extension NSRecursiveLock {
  @inlinable @discardableResult
  @_spi(Internals) public func sync<R>(work: () -> R) -> R {
    self.lock()
    defer { self.unlock() }
    return work()
  }
}
