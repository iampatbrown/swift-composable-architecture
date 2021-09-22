import ComposableArchitecture
import Foundation

struct AudioPlayerClient {
  var play: (Sound) -> Effect<Never, Never>

  enum Sound: CaseIterable {
    case ding
  }
}
