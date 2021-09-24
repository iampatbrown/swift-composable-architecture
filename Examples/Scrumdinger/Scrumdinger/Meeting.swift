import ComposableArchitecture
import Speech
import SwiftUI

struct Meeting: Equatable {
  var activeSpeakerIndex: Int = 0
  var scrumColor: Color = .orange
  var isRecording = false
  var isTimerActive: Bool = false
  var lengthInMinutes: Int = 5
  var secondsElapsed: Int = 0
  var speakers: [Speaker] = []
  var transcript = ""

  struct Speaker: Equatable, Identifiable {
    let name: String
    var isCompleted: Bool = false
    let id = UUID()
  }

  var attendees: [String] { speakers.map(\.name) }
  var lengthInSeconds: Int { lengthInMinutes * 60 }
  var secondsElapsedForSpeaker: Int { secondsElapsed - Int(secondsPerSpeaker * Double(activeSpeakerIndex)) }
  var secondsPerSpeaker: Double { Double(lengthInMinutes * 60) / Double(max(speakers.count, 1)) }
  var secondsRemaining: Int { max(lengthInSeconds - secondsElapsed, 0) }
}

enum MeetingAction: Equatable, LifecycleAction {
  case skipSpeaker
  case onAppear
  case onDisappear
  case recordPermissionResponse(Bool)
  case speech(Result<SpeechClient.Action, SpeechClient.Error>)
  case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
  case timerTicked
}

struct MeetingEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
}

private struct SpeechRecognitionId: Hashable {}
private struct TimerId: Hashable {}

let meetingReducer = Reducer<Meeting, MeetingAction, MeetingEnvironment> { state, action, environment in
  func startRecording() -> Effect<MeetingAction, Never> {
    state.isRecording = true
    let request = SFSpeechAudioBufferRecognitionRequest(shouldReportPartialResults: true)
    return environment.speechClient.recognitionTask(request)
      .catchToEffect(MeetingAction.speech)
      .cancellable(id: SpeechRecognitionId())
  }

  func startTimer() -> Effect<MeetingAction, Never> {
    state.isTimerActive = true
    return Effect.timer(id: TimerId(), every: 1, tolerance: .zero, on: environment.mainQueue)
      .map { _ in MeetingAction.timerTicked }
  }

  func finishMeeting() -> Effect<MeetingAction, Never> {
    state.isRecording = false
    state.isTimerActive = false
    return .merge(
      environment.speechClient.finishTask().fireAndForget(),
      Effect.cancel(id: TimerId())
    )
  }

  func nextSpeaker() -> Effect<MeetingAction, Never> {
    state.speakers[state.activeSpeakerIndex].isCompleted = true
    let nextIndex = state.activeSpeakerIndex + 1
    state.secondsElapsed = Int(state.secondsPerSpeaker * Double(nextIndex))
    if nextIndex < state.speakers.count {
      state.activeSpeakerIndex = nextIndex
      return .none
    } else {
      return finishMeeting()
    }
  }

  switch action {
  case .skipSpeaker:
    return nextSpeaker()

  case .onAppear:
    return .none

  case .onDisappear:
    return .none

  case let .recordPermissionResponse(permission):
    if permission {
      return environment.speechClient.requestAuthorization()
        .receive(on: environment.mainQueue)
        .map(MeetingAction.speechRecognizerAuthorizationStatusResponse)
        .eraseToEffect()
    } else {
      return startTimer()
    }

  case let .speech(.success(.availabilityDidChange(isAvailable))):
    return .none

  case let .speech(.success(.taskResult(result))):
    state.transcript = result.bestTranscription.formattedString
    if result.isFinal {
      state.isRecording = false
      return environment.speechClient.finishTask().fireAndForget()

    } else {
      return .none
    }

  case let .speech(.failure(error)):
    state.isRecording = false
    return environment.speechClient.finishTask()
      .fireAndForget()

  case let .speechRecognizerAuthorizationStatusResponse(status):
    if status == .authorized { // TODO: Maybe add alerts
      return .merge(
        startRecording(),
        startTimer()
      )
    } else {
      return startTimer()
    }

  case .timerTicked:
    state.secondsElapsed += 1
    if state.secondsElapsedForSpeaker >= Int(state.secondsPerSpeaker) {
      return .merge(
        environment.audioPlayerClient.play(.ding).fireAndForget(),
        nextSpeaker()
      )
    } else {
      return .none
    }
  }
}.lifecycle { state, action, environment in
  switch action {
  case .onAppear:
    return environment.speechClient.requestRecordPermission()
      .receive(on: environment.mainQueue)
      .map(MeetingAction.recordPermissionResponse)
      .eraseToEffect()

  case .onDisappear:
    return .merge(
      Effect.cancel(id: SpeechRecognitionId()),
      Effect.cancel(id: TimerId())
    )
  default:
    return .none
  }
}

struct MeetingView: View {
  let store: Store<Meeting, MeetingAction>

  struct ViewState: Equatable {
    let scrumColor: Color

    init(state: Meeting) {
      self.scrumColor = state.scrumColor
    }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      ZStack {
        RoundedRectangle(cornerRadius: 16.0)
          .fill(viewStore.scrumColor)
        VStack {
          MeetingHeaderView(store: self.store)
          MeetingTimerView(store: self.store)
          MeetingFooterView(store: self.store)
        }
      }
      .padding()
      .foregroundColor(viewStore.scrumColor.accessibleFontColor)
      .onAppear { viewStore.send(.onAppear) }
      .onDisappear { viewStore.send(.onDisappear) }
    }
  }
}
