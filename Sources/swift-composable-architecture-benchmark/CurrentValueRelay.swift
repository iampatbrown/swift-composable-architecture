import Benchmark
import Combine
import ComposableArchitecture
import Foundation

typealias Relay = CurrentValueRelay<Void>
// typealias Relay = CurrentValueSubject<Void, Never>
// typealias Relay = CurrentValueRelayOld<Void>

let subscriberLevels = 4
let eventLevels = 4

let currentValueRelaySuite = BenchmarkSuite(name: typeName(Relay.self)) { suite in

  var relay = Relay(())
  var cancellables = ContiguousArray<AnyCancellable>()
  var results = [Int]()

  for subscriberN in 0..<subscriberLevels {
    let subscriberCount = Int(pow(10, Double(subscriberN)))

    suite.benchmark("subscribe (\(subscriberCount))") {
      for n in 0..<subscriberCount {
        relay.sink { results.append(n) }.store(in: &cancellables)
      }
    } setUp: {
      relay = .init(())
      cancellables = []
      results = []
    } tearDown: {
      precondition(results == Array(0..<subscriberCount))
      precondition(cancellables.count == subscriberCount)
    }

    suite.benchmark("cancel (\(subscriberCount))") {
      cancellables.forEach { $0.cancel() }
    } setUp: {
      relay = .init(())
      cancellables = []
      results = []
      for n in 0..<subscriberCount {
        relay.handleEvents(receiveCancel: { results.append(n) }).sink {}.store(in: &cancellables)
      }
    } tearDown: {
      precondition(results.sorted() == Array(0..<subscriberCount))
      precondition(cancellables.count == subscriberCount)
    }

    for eventN in 0..<eventLevels {
      let eventCount = Int(pow(10, Double(eventN)))

      suite.benchmark("send × \(eventCount) (\(subscriberCount))") {
        for _ in 0..<eventCount {
          relay.send(())
        }
      } setUp: {
        relay = .init(())
        cancellables = []
        for n in 0..<subscriberCount {
          relay.sink { results.append(n) }.store(in: &cancellables)
        }
        results = []
      } tearDown: {
        let expected = (0..<eventCount).flatMap { _ in Array(0..<subscriberCount) }
        if Relay.self == CurrentValueSubject<Void, Never>.self {
          precondition(results.sorted() == expected.sorted())
        } else {
          precondition(results == expected)
        }
        precondition(cancellables.count == subscriberCount)
      }
    }
  }

  suite.benchmarks.sort(by: { $0.name < $1.name })
}
