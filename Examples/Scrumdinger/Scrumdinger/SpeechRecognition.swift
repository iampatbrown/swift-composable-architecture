import ComposableArchitecture
import Speech
import SwiftUI

struct SpeechRecognition {
  var isRecording = false
  var speechRecognizerAuthorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined
  var transcribedText = ""
}

enum SpeechRecognitionAction {
  case recordPermissionResponse(Bool)
  case speech(Result<SpeechClient.Action, SpeechClient.Error>)
  case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
}

struct SpeechRecognitionEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
}

let speechRecognitionReducer = Reducer<
  SpeechRecognition,
  SpeechRecognitionAction,
  SpeechRecognitionEnvironment
> { state, action, environment in
  return .none
}
