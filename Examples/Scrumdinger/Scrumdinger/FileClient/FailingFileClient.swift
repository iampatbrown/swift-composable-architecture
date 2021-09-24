import ComposableArchitecture

extension FileClient {
  static let failing = Self(
    delete: { .failing("\(Self.self).delete(\($0)) is unimplemented") },
    load: { .failing("\(Self.self).load(\($0)) is unimplemented") },
    save: { file, _ in .failing("\(Self.self).save(\(file)) is unimplemented") }
  )
}
