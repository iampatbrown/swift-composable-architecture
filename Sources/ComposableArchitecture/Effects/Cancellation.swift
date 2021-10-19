import Combine
import Foundation

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// ``Effect/cancel(id:)`` to identify which in-flight effect should be canceled. Any hashable
  /// value can be used for the identifier, such as a string, but you can add a bit of protection
  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
  ///
  /// ```swift
  /// struct LoadUserId: Hashable {}
  ///
  /// case .reloadButtonTapped:
  ///   // Start a new effect to load the user
  ///   return environment.loadUser
  ///     .map(Action.userResponse)
  ///     .cancellable(id: LoadUserId(), cancelInFlight: true)
  ///
  /// case .cancelButtonTapped:
  ///   // Cancel any in-flight requests to load the user
  ///   return .cancel(id: LoadUserId())
  /// ```
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
    let effect = Deferred { () -> Publishers.HandleEvents<PassthroughSubject<Output, Failure>> in
      cancellablesLock.lock()
      defer { cancellablesLock.unlock() }

      let subject = PassthroughSubject<Output, Failure>()
      let cancellable = self.subscribe(subject)

      var cancellationCancellable: AnyCancellable!
      cancellationCancellable = AnyCancellable {
        cancellablesLock.sync {
          subject.send(completion: .finished)
          cancellable.cancel()
          cancellationCancellables[id]?.remove(cancellationCancellable)
          if cancellationCancellables[id]?.isEmpty == .some(true) {
            cancellationCancellables[id] = nil
          }
        }
      }

      cancellationCancellables[id, default: []].insert(
        cancellationCancellable
      )

      return subject.handleEvents(
        receiveCompletion: { _ in cancellationCancellable.cancel() },
        receiveCancel: cancellationCancellable.cancel
      )
    }
    .eraseToEffect()

    return cancelInFlight ? .concatenate(.cancel(id: id), effect) : effect
  }

  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable) -> Effect {
    return .fireAndForget {
      cancellablesLock.sync {
        cancellationCancellables[id]?.forEach { $0.cancel() }
      }
    }
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// - Parameter ids: A variadic list of effect identifiers.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: AnyHashable...) -> Effect {
    .cancel(ids: ids)
  }

  /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
  ///
  /// - Parameter ids: An array of effect identifiers.
  /// - Returns: A new effect that will cancel any currently in-flight effects with the given
  ///   identifiers.
  public static func cancel(ids: [AnyHashable]) -> Effect {
    .merge(ids.map(Effect.cancel(id:)))
  }
}

var cancellationCancellables: [AnyHashable: Set<AnyCancellable>] = [:]
let cancellablesLock = NSRecursiveLock()

public final class EffectCanceller {
  var cancellables: [AnyHashable: Set<AnyCancellable>] = [:]

  public init() {}

  public func register<P: Publisher>(
    _ publisher: P,
    id: AnyHashable,
    cancelInFlight: Bool = false
  ) -> Effect<P.Output, P.Failure> {
    return Deferred { () -> Publishers.HandleEvents<PassthroughSubject<P.Output, P.Failure>> in
      if cancelInFlight { self.cancel(id: id) }

      let downstream = PassthroughSubject<P.Output, P.Failure>()
      let upstream = publisher.subscribe(downstream)
      var cancellable: AnyCancellable!

      cancellable = AnyCancellable { [weak self] in
        downstream.send(completion: .finished)
        upstream.cancel()
        guard let self = self else { return }
        self.cancellables[id]?.remove(cancellable)
        if self.cancellables[id]?.isEmpty == .some(true) {
          self.cancellables[id] = nil
        }
      }

      self.cancellables[id, default: []].insert(cancellable)

      return downstream.handleEvents(
        receiveCompletion: { _ in cancellable.cancel() },
        receiveCancel: cancellable.cancel
      )
    }.eraseToEffect()
  }

  public func cancel(id: AnyHashable) {
    self.cancellables[id]?.forEach { $0.cancel() }
  }

  public func cancel(ids: AnyHashable...) {
    self.cancel(ids: ids)
  }

  public func cancel(ids: [AnyHashable]) {
    ids.forEach(self.cancel)
  }

  public func cancelAll() {
    self.cancellables.keys.forEach(self.cancel)
  }

  deinit {
    self.cancelAll()
  }
}

extension Effect {
  public func cancellable(
    with canceller: EffectCanceller,
    id: AnyHashable,
    cancelInFlight: Bool = false
  ) -> Effect {
    canceller.register(self, id: id, cancelInFlight: cancelInFlight)
  }

  public static func cancel(with canceller: EffectCanceller, id: AnyHashable) -> Effect {
    return .fireAndForget {
      canceller.cancel(id: id)
    }
  }

  public static func cancel(with canceller: EffectCanceller, ids: AnyHashable...) -> Effect {
    .cancel(ids: ids)
  }

  public static func cancel(with canceller: EffectCanceller, ids: [AnyHashable]) -> Effect {
    .merge(ids.map { Effect.cancel(with: canceller, id: $0) })
  }
}
