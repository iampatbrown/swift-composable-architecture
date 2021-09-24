import ComposableArchitecture
@testable import Scrumdinger
import XCTest

class ScrumsTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testLoadScrums_WhenFileNotFound_ShouldLoadMockScums() {
    let store = TestStore(
      initialState: Scrums(),
      reducer: scrumsReducer,
      environment: ScrumsEnvironment(
        audioPlayerClient: .failing,
        mainQueue: scheduler.eraseToAnyScheduler(),
        speechClient: .failing,
        uuid: UUID.incrementing
      )
    )
  }
}

extension UUID {
  // A deterministic, auto-incrementing "UUID" generator for testing.
  static var incrementing: () -> UUID {
    var uuid = 0
    return {
      defer { uuid += 1 }
      return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
    }
  }
}
