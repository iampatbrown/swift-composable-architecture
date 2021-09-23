import ComposableArchitecture
import SwiftUI

struct Scrum: Equatable, Identifiable {
  var attendees: [String] = []
  var color: Color = .orange
  var history: [History] = []
  var id = UUID()
  var isMeetingActive: Bool = false
  var lengthInMinutes: Int = 5
  var meeting: Meeting?
  var pendingChanges: EditState?
  var title: String = ""

  struct History: Equatable, Identifiable {
    var attendees: [String] = []
    var date = Date()
    var id = UUID()
    var lengthInMinutes: Int
    var transcript: String?
  }

  mutating func applyChanges() {
    guard let changes = self.pendingChanges else { return }
    self.attendees = changes.attendees
    self.color = changes.color
    self.lengthInMinutes = Int(changes.lengthInMinutes)
    self.title = changes.title
    self.pendingChanges = nil
  }
}

enum ScrumAction {
  case applyChanges
  case edit(EditAction)
  case meeting(MeetingAction)
  case saveMeeting
  case setIsEditing(Bool)
  case setIsMeetingActive(Bool)
}

struct ScrumEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
}

let scrumReducer = Reducer<Scrum, ScrumAction, ScrumEnvironment>.combine(
  editReducer.optional()
    .pullback(
      state: \Scrum.pendingChanges,
      action: /ScrumAction.edit,
      environment: { _ in EditEnvironment() }
    ),

  meetingReducer
    .optional()
    .pullback(
      state: \Scrum.meeting,
      action: /ScrumAction.meeting,
      environment: {
        MeetingEnvironment(
          audioPlayerClient: $0.audioPlayerClient,
          mainQueue: $0.mainQueue,
          speechClient: $0.speechClient
        )
      }
    ),

  Reducer { state, action, environment in
    switch action {
    case .applyChanges:
      state.applyChanges()
      return .none

    case .edit:
      return .none

    case .meeting(.onDisappear):
      return .none

    case .meeting:
      return .none

    case .saveMeeting:
      if let newHistory = state.meeting.map(Scrum.History.init) {
        state.history.insert(newHistory, at: 0)
        state.meeting = nil
      }
      return .none

    case .setIsEditing(true):
      guard state.pendingChanges == nil else { return .none }
      state.pendingChanges = EditState(state: state)
      return .none

    case .setIsEditing(false):
      state.pendingChanges = nil
      return .none

    case .setIsMeetingActive(true):
      state.isMeetingActive = true
      state.meeting = Meeting(state: state)
      return .none

    case .setIsMeetingActive(false):
      state.isMeetingActive = false
      return Effect(value: .saveMeeting)
        .deferred(for: 0.2, scheduler: environment.mainQueue) // TODO: Fix this
    }
  }
)

struct ScrumView: View {
  let store: Store<Scrum, ScrumAction>

  struct ViewState: Equatable {
    let attendees: [String]
    let color: Color
    let history: [Scrum.History]
    let lengthInMinutes: Int
    let isEditing: Bool
    let isMeetingActive: Bool
    let title: String

    init(state: Scrum) {
      self.attendees = state.attendees
      self.color = state.color
      self.history = state.history
      self.lengthInMinutes = state.lengthInMinutes
      self.isEditing = state.pendingChanges != nil
      self.isMeetingActive = state.isMeetingActive
      self.title = state.title
    }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      List {
        Section(header: Text("Meeting Info")) {
          NavigationLink(
            isActive: viewStore.binding(
              get: \.isMeetingActive,
              send: ScrumAction.setIsMeetingActive
            ),
            destination: {
              IfLetStore(
                self.store.scope(
                  state: \Scrum.meeting,
                  action: ScrumAction.meeting
                ),
                then: MeetingView.init(store:)
              )
            },
            label: {
              Label("Start Meeting", systemImage: "timer")
                .font(.headline)
                .foregroundColor(.accentColor)
                .accessibilityLabel(Text("start meeting"))
            }
          )

          HStack {
            Label("Length", systemImage: "clock")
              .accessibilityLabel(Text("meeting length"))
            Spacer()
            Text("\(viewStore.lengthInMinutes) minutes")
          }
          HStack {
            Label("Color", systemImage: "paintpalette")
            Spacer()
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(viewStore.color)
          }
          .accessibilityElement(children: .ignore)
        }
        Section(header: Text("Attendees")) {
          ForEach(viewStore.attendees, id: \.self) { attendee in
            Label(attendee, systemImage: "person")
              .accessibilityLabel(Text("person"))
              .accessibilityValue(Text(attendee))
          }
        }

        Section(header: Text("History")) {
          if viewStore.history.isEmpty {
            Label("No meetings yet", systemImage: "calendar.badge.exclamationmark")
          }
          ForEach(viewStore.history) { history in
            NavigationLink(
              destination: HistoryView(history: history)
            ) {
              HStack {
                Image(systemName: "calendar")
                Text(history.date, style: .date)
              }
            }
          }
        }
      }
      .listStyle(InsetGroupedListStyle())
      .navigationBarItems(
        trailing: Button("Edit") { viewStore.send(.setIsEditing(true)) }
      )
      .navigationTitle(viewStore.title)
      .fullScreenCover(
        isPresented: viewStore.binding(
          get: \.isEditing,
          send: ScrumAction.setIsEditing
        )
      ) {
        NavigationView {
          IfLetStore(
            self.store.scope(
              state: \Scrum.pendingChanges,
              action: ScrumAction.edit
            ),
            then: EditView.init(store:)
          )
          .navigationTitle(viewStore.title)
          .navigationBarItems(
            leading: Button("Cancel") { viewStore.send(.setIsEditing(false)) },
            trailing: Button("Done") { viewStore.send(.applyChanges) }
          )
        }
      }
    }
  }
}

extension EditState {
  init(state: Scrum) {
    self.attendees = state.attendees
    self.color = state.color
    self.lengthInMinutes = Double(state.lengthInMinutes)
    self.title = state.title
  }
}

extension Scrum.History {
  init(state: Meeting) {
    self.attendees = state.attendees
    self.lengthInMinutes = state.secondsElapsed
    self.transcript = state.transcript
  }
}

extension Meeting {
  init(state: Scrum) {
    self.lengthInMinutes = state.lengthInMinutes
    self.scrumColor = state.color
    self.speakers = state.attendees.isEmpty ? [Speaker(name: "Someone")] : state.attendees.map { Speaker(name: $0) }
  }
}
