import Combine
import Foundation

public final class CurrentValueRelay<Output>: Publisher {
  public typealias Failure = Never

  private var currentValue: Output
  private let lock: os_unfair_lock_t
  private var subscriptions = ContiguousArray<Subscription>()

  var value: Output {
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
    let subscription = Subscription(upstream: self, downstream: subscriber)
    self.lock.sync {
      self.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  public func send(_ value: Output) {
    self.currentValue = value
    for subscription in self.subscriptions {
      subscription.receive(value)
    }
  }

  private func remove(_ subscription: Subscription) {
    self.lock.sync {
      guard let index = self.subscriptions.firstIndex(of: subscription)
      else { return }
      self.subscriptions.remove(at: index)
    }
  }
}

extension CurrentValueRelay {
  fileprivate final class Subscription: Combine.Subscription, Equatable {
    private var demand = Subscribers.Demand.none
    private var downstream: (any Subscriber<Output, Never>)?
    private let lock: os_unfair_lock_t
    private var receivedLastValue = false
    private var upstream: CurrentValueRelay?

    init(upstream: CurrentValueRelay, downstream: any Subscriber<Output, Never>) {
      self.upstream = upstream
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
        self.upstream?.remove(self)
        self.upstream = nil
      }
    }

    func receive(_ value: Output) {
      guard let downstream else { return }

      switch self.demand {
      case .unlimited:
        // NB: Adding to unlimited demand has no effect and can be ignored.
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

      guard let downstream else { return }

      self.lock.lock()
      self.demand += demand

      guard
        !self.receivedLastValue,
        let value = self.upstream?.currentValue
      else {
        self.lock.unlock()
        return
      }

      self.receivedLastValue = true

      switch self.demand {
      case .unlimited:
        self.lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(value)

      default:
        self.demand -= 1
        self.lock.unlock()
        let moreDemand = downstream.receive(value)
        self.lock.lock()
        self.demand += moreDemand
        self.lock.unlock()
      }
    }

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      lhs === rhs
    }
  }
}



public final class CurrentValueRelayOld<Output>: Publisher {
  public typealias Failure = Never

  private var currentValue: Output
  private var subscriptions: [Subscription<AnySubscriber<Output, Failure>>] = []

  var value: Output {
    get { self.currentValue }
    set { self.send(newValue) }
  }

  public init(_ value: Output) {
    self.currentValue = value
  }

  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    let subscription = Subscription(downstream: AnySubscriber(subscriber))
    self.subscriptions.append(subscription)
    subscriber.receive(subscription: subscription)
    subscription.forwardValueToBuffer(self.currentValue)
  }

  public func send(_ value: Output) {
    self.currentValue = value
    for subscription in subscriptions {
      subscription.forwardValueToBuffer(value)
    }
  }
}

extension CurrentValueRelayOld {
  final class Subscription<Downstream: Subscriber>: Combine.Subscription
  where Downstream.Input == Output, Downstream.Failure == Failure {
    private var demandBuffer: DemandBuffer<Downstream>?

    init(downstream: Downstream) {
      self.demandBuffer = DemandBuffer(subscriber: downstream)
    }

    func forwardValueToBuffer(_ value: Output) {
      _ = demandBuffer?.buffer(value: value)
    }

    func request(_ demand: Subscribers.Demand) {
      _ = demandBuffer?.demand(demand)
    }

    func cancel() {
      demandBuffer = nil
    }
  }
}
