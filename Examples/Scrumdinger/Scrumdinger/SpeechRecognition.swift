import ComposableArchitecture
import Speech
import SwiftUI

struct SpeechRecognition: Equatable {
  var alert: AlertState<SpeechRecognitionAction>?
  var authorizationStatus = SpeechClient.AuthorizationStatus.notDetermined
  var isRecording = false
  var transcribedText = ""

}

enum SpeechRecognitionAction: Equatable {
  case alertDismissed
  case authorizationStatusResponse(SpeechClient.AuthorizationStatus)
  case speech(Result<SpeechClient.Action, SpeechClient.Error>)
  case startTask
  case finishTask
}

struct SpeechRecognitionEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
}

let speechRecognitionReducer = Reducer<
  SpeechRecognition,
  SpeechRecognitionAction,
  SpeechRecognitionEnvironment
> { state, action, environment in

  switch action {
  case .alertDismissed:
    state.alert = nil
    return .none

  case let .authorizationStatusResponse(status):
    state.authorizationStatus = status == .notDetermined ? .unknown : status
    return Effect(value: .startTask)

  case let .speech(.success(.availabilityDidChange(isAvailable))):
    // TODO: Test this out
    return .none

  case let .speech(.success(.taskResult(result))):
    state.transcribedText = result.bestTranscription.formattedString
    if result.isFinal {
      return Effect(value: .finishTask)
    } else {
      return .none
    }

  case let .speech(.failure(error)):
    state.alert = .init(title: .init("An error occured while transcribing. Please try again."))
    return Effect(value: .finishTask)

  case .finishTask:
    guard state.isRecording else { return .none }
    state.isRecording = false
    return environment.speechClient.finishTask()
      .fireAndForget()

  case .startTask:
    guard !state.isRecording else {
      state.alert = .init(title: .init("Speech recognition task already in progress."))
      return .none
    }
    switch state.authorizationStatus {
    case .authorized:
      state.isRecording = true
      let request = SFSpeechAudioBufferRecognitionRequest(shouldReportPartialResults: true)
      return environment.speechClient.recognitionTask(request)
        .catchToEffect(SpeechRecognitionAction.speech)

    case .deniedRecordPermission:
      state.alert = .init(
        title: .init(
          """
          Access to microphone was denied. This app needs access to transcribe your speech.
          """
        )
      )
      return .none

    case .denied:
      state.alert = .init(
        title: .init(
          """
          Access to speech recognition was denied. This app needs access to transcribe your speech.
          """
        )
      )
      return .none

    case .restricted:
      state.alert = .init(title: .init("Your device does not allow speech recognition."))
      return .none

    case .notDetermined:
      return environment.speechClient.requestAuthorization()
        .receive(on: environment.mainQueue)
        .map(SpeechRecognitionAction.authorizationStatusResponse)
        .eraseToEffect()

    case .unknown:
      state.alert = .init(title: .init("Speech recognition permissions were unable to be determined."))
      return .none
    }
  }
}
