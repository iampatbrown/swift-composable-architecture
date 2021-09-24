import ComposableArchitecture

extension AudioPlayerClient {
  static let failing = Self(
    play: { .failing("\(Self.self).play(\($0)) is unimplemented") }
  )
}
