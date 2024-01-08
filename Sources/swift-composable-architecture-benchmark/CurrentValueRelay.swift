import Benchmark
import Combine
import ComposableArchitecture
import Foundation

let currentValueRelaySuite = BenchmarkSuite(name: "CurrentValueRelay") { suite in
//  typealias Relay<Output> = CurrentValueSubject<Output, Never>
  typealias Relay<Output> = CurrentValueRelay<Output>

//  for subscriberCount in 1...5 {
//    do {
//      var subject: Relay<Void>!
//      var cancellables: Set<AnyCancellable>!
//      var result: Int!
//      suite.benchmark("subscribe (\(subscriberCount))") {
//        for _ in 1...subscriberCount {
//          subject.sink { result += 1 }
//            .store(in: &cancellables)
//        }
//      } setUp: {
//        subject = .init(())
//        cancellables = .init()
//        result = 0
//      } tearDown: {
//        precondition(cancellables.count == subscriberCount)
//        precondition(result == subscriberCount)
//        cancellables.forEach { $0.cancel() }
//      }
//    }
//  }
//
//  for subscriberCount in 1...3 {
//    for eventCount in 1...3 {
//      do {
//        var subject: Relay<Void>!
//        var cancellables: Set<AnyCancellable>!
//        var result = 0
//        suite.benchmark("send × \(eventCount) (\(subscriberCount))") {
//          for _ in 1...eventCount {
//            subject.send()
//          }
//        } setUp: {
//          subject = .init(())
//          cancellables = .init()
//          for _ in 1...subscriberCount {
//            subject.sink { result += 1 }
//              .store(in: &cancellables)
//          }
//          result = 0
//        } tearDown: {
//          precondition(cancellables.count == subscriberCount)
//          precondition(result == subscriberCount * eventCount)
//          cancellables.forEach { $0.cancel() }
//        }
//      }
//    }
//  }
//
//  for subscriberCount in [1, 10, 100] {
//    do {
//      var subject: Relay<Void>!
//      var cancellables: Set<AnyCancellable>!
//      var result = 0
//      suite.benchmark("cancel (\(subscriberCount))") {
//        cancellables.forEach { $0.cancel() }
//      } setUp: {
//        subject = .init(())
//        cancellables = .init()
//        for _ in 1...subscriberCount {
//          subject
//            .handleEvents(receiveCancel: { result += 1 })
//            .sink {}
//            .store(in: &cancellables)
//        }
//        result = 0
//      } tearDown: {
//        precondition(cancellables.count == subscriberCount)
//        precondition(result == subscriberCount)
//      }
//    }
//  }
//
//  for subscriberCount in [1, 10, 100] {
//    for eventCount in [1, 10, 100] {
//      do {
//        var subject: Relay<Void>!
//        var cancellables: Set<AnyCancellable>!
//        var result = 0
//        suite.benchmark("subscribe, send × \(eventCount), cancel (\(subscriberCount))") {
//          for _ in 1...subscriberCount {
//            subject
//              .handleEvents(receiveCancel: { result -= 1 })
//              .sink { result += 1 }
//              .store(in: &cancellables)
//          }
//          for _ in 1...eventCount {
//            subject.send()
//          }
//          cancellables.forEach { $0.cancel() }
//        } setUp: {
//          subject = .init(())
//          cancellables = .init()
//          result = 0
//        } tearDown: {
//          precondition(cancellables.count == subscriberCount)
//          precondition(result == subscriberCount * eventCount)
//        }
//      }
//    }
//  }

  for subscriberCount in [1, 10, 100] {
    for eventCount in [1, 10, 100] {
      do {
        var subject: Relay<Void>!
        var cancellables: Set<AnyCancellable>!
        var result = 0
        suite.benchmark("subscribe, send 1, cancel (\(subscriberCount)) × \(eventCount)") {
          for _ in 1...eventCount {
            for _ in 1...subscriberCount {
              subject
                .handleEvents(receiveCancel: { result -= 1 })
                .sink { result += 1 }
                .store(in: &cancellables)
            }
            subject.send()
            cancellables.forEach { $0.cancel() }
          }
        } setUp: {
          subject = .init(())
          cancellables = .init()
          result = 0
        } tearDown: {
          precondition(cancellables.count == subscriberCount * eventCount)
          precondition(result == subscriberCount * eventCount)
        }
      }
    }
  }
}
