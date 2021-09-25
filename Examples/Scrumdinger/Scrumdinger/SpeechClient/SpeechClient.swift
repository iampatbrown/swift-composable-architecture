import ComposableArchitecture
import Speech

struct SpeechClient {
  var finishTask: () -> Effect<Never, Never>
  var recognitionTask: (SFSpeechAudioBufferRecognitionRequest) -> Effect<Action, Error>
  var requestAuthorization: () -> Effect<AuthorizationStatus, Never>

  enum Action: Equatable {
    case availabilityDidChange(isAvailable: Bool)
    case taskResult(SpeechRecognitionResult)
  }

  enum Error: Swift.Error, Equatable {
    case taskError(NSError)
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }

  enum AuthorizationStatus {
    case authorized
    case deniedRecordPermission
    case denied
    case restricted
    case notDetermined
    case unknown
  }
}
