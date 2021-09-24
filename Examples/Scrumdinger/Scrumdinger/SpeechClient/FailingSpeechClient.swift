import ComposableArchitecture

extension SpeechClient {
  static let failing = Self(
    finishTask: { .failing("\(Self.self).finishTask() is unimplemented") },
    recognitionTask: { .failing("\(Self.self).recognitionTask(\($0)) is unimplemented") },
    requestAuthorization: { .failing("\(Self.self).requestAuthorization() is unimplemented") },
    requestRecordPermission: { .failing("\(Self.self).requestRecordPermission() is unimplemented") }
  )
}
