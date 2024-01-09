import Combine
import Foundation
import OrderedCollections

public final class CurrentValueRelay<Output>: Publisher {
  public typealias Failure = Never

  fileprivate var currentValue: Output
  private var downstreams = ConduitList.empty
  private let lock: os_unfair_lock_t // TODO: Want to use NSLock instead? Or create a wrapper?

  var value: Output { // TODO: Do we want to lock value access?
    get { self.currentValue }
    set { self.send(newValue) }
  }

  public init(_ value: Output) {
    self.currentValue = value
    self.lock = os_unfair_lock_t.allocate(capacity: 1)
    self.lock.initialize(to: os_unfair_lock())
  }

  deinit {
    self.lock.deinitialize(count: 1)
    self.lock.deallocate()
  }

  public func receive(subscriber: some Subscriber<Output, Never>) {
    let conduit = Conduit(parent: self, downstream: subscriber)
    self.lock.sync {
      self.downstreams.append(conduit)
    }
    subscriber.receive(subscription: conduit)
  }

  public func send(_ value: Output) {
    self.currentValue = value
    self.downstreams.forEach {
      $0.forward(value)
    }
  }

  private func remove(_ conduit: Conduit) {
    self.lock.sync {
      self.downstreams.remove(conduit)
    }
  }

  fileprivate final class Conduit: Subscription, Hashable {
    private var demand = Subscribers.Demand.none
    private var downstream: (any Subscriber<Output, Never>)?
    private let lock: os_unfair_lock_t
    private var parent: CurrentValueRelay?
    private var receivedLastValue = false

    init(parent: CurrentValueRelay, downstream: any Subscriber<Output, Never>) {
      self.parent = parent
      self.downstream = downstream
      self.lock = os_unfair_lock_t.allocate(capacity: 1)
      self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
      self.lock.deinitialize(count: 1)
      self.lock.deallocate()
    }

    func cancel() {
      self.lock.sync {
        self.downstream = nil
        self.parent?.remove(self)
        self.parent = nil
      }
    }

    func forward(_ value: Output) {
      guard let downstream else {
        return
      }

      switch self.demand {
      case .unlimited:
        // When the demand is unlimited all values are forwarded
        _ = downstream.receive(value)

      case .none:
        self.lock.sync {
          self.receivedLastValue = false
        }

      default:
        self.lock.sync {
          self.receivedLastValue = true
          self.demand -= 1
        }
        let moreDemand = downstream.receive(value)
        self.lock.sync {
          self.demand += moreDemand
        }
      }
    }

    func request(_ demand: Subscribers.Demand) {
      precondition(demand > 0, "Demand must be greater than zero")
      guard let downstream else {
        return
      }

      self.lock.lock()
      self.demand += demand

      guard
        !self.receivedLastValue,
        let value = parent?.currentValue
      else {
        self.lock.unlock()
        return
      }

      self.receivedLastValue = true

      switch self.demand {
      case .unlimited:
        self.lock.unlock()
        // When the demand is unlimited all values are forwarded
        _ = downstream.receive(value)

      default:
        self.demand -= 1
        self.lock.unlock()
        let moreDemand = downstream.receive(value)
        self.lock.sync {
          self.demand += moreDemand
        }
      }
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }

    static func == (lhs: Conduit, rhs: Conduit) -> Bool {
      ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
  }

  private enum ConduitList {
    case empty
    case single(Conduit)
    case many(ContiguousArray<Conduit>)

    mutating func append(_ newConduit: Conduit) {
      switch self {
      case .empty:
        self = .single(newConduit)
      case let .single(conduit):
        self = .many([conduit, newConduit])
      case var .many(array):
        array.append(newConduit)
        self = .many(array)
      }
    }

    func forEach(_ body: (Conduit) -> Void) {
      switch self {
      case .empty:
        return
      case let .single(conduit):
        body(conduit)
      case let .many(array):
        array.forEach(body)
      }
    }

    mutating func remove(_ conduit: Conduit) {
      switch self {
      case .single(conduit):
        self = .empty
      case .empty, .single:
        return
      case var .many(array):
        guard let index = array.firstIndex(of: conduit)
        else { return }
        array.remove(at: index)
        self = .many(array)
      }
    }
  }
}

extension CurrentValueRelay<Void> {
  @inlinable
  public func send() {
    self.send(())
  }
}
