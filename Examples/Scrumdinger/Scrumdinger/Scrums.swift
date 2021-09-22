import ComposableArchitecture
import SwiftUI

struct AppState: Equatable {
  var newScrum: EditState?
  var scrums: IdentifiedArrayOf<Scrum> = []
  var selection: Identified<Scrum.ID, Scrum>?
}

enum AppAction {
  case addNewScrum
  case newScrum(EditAction)
  case onLaunch
  case scenePhaseChanged(ScenePhase)
  case scrum(ScrumAction)
  case scrumsLoaded(Result<[Scrum], Error>)
  case setIsAddingScrum(Bool)
  case setNavigation(selection: Scrum.ID?)
}

struct AppEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var backgroundQueue: AnySchedulerOf<DispatchQueue>
  var fileClient: FileClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
  var uuid: () -> UUID
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  scrumReducer
    .pullback(state: \Identified.value, action: .self, environment: { $0 })
    .optional()
    .pullback(
      state: \AppState.selection,
      action: /AppAction.scrum,
      environment: {
        ScrumEnvironment(
          audioPlayerClient: $0.audioPlayerClient,
          mainQueue: $0.mainQueue,
          speechClient: $0.speechClient
        )
      }
    ),

  editReducer
    .optional()
    .pullback(
      state: \AppState.newScrum,
      action: /AppAction.newScrum,
      environment: { _ in EditEnvironment() }
    ),

  Reducer { state, action, environment in
    switch action {
    case .addNewScrum:
      if let newScrum = state.newScrum {
        let id = environment.uuid()
        state.scrums.append(Scrum(id: id, state: newScrum))
        state.newScrum = nil
      }
      return .none

    case .newScrum:
      return .none

    case .onLaunch:
      return environment.fileClient.load()
        .subscribe(on: environment.backgroundQueue)
        .receive(on: environment.mainQueue.animation())
        .catchToEffect(AppAction.scrumsLoaded)

    case let .scenePhaseChanged(scenePhase):
      if scenePhase == .inactive {
        return environment.fileClient.save(Array(state.scrums))
          .subscribe(on: environment.backgroundQueue)
          .receive(on: environment.mainQueue)
          .fireAndForget()
      } else {
        return .none
      }

    case .scrum(.applyChanges):
      guard let selection = state.selection else { return .none }
      state.scrums[id: selection.id] = selection.value
      return .none

    case .scrum(.saveMeeting):
      guard let selection = state.selection else { return .none }
      state.scrums[id: selection.id]?.history = selection.value.history
      return .none

    case .scrum:
      return .none

    case let .scrumsLoaded(.success(scrums)):
      state.scrums = .init(uniqueElements: scrums)
      return .none

    case let .scrumsLoaded(.failure(error as NSError)):
      if error.code == NSFileReadNoSuchFileError {
        state.scrums = .mock
      }
      return .none

    case .setIsAddingScrum(true):
      state.newScrum = EditState()
      return .none

    case .setIsAddingScrum(false):
      state.newScrum = nil
      return .none

    case let .setNavigation(selection: .some(id)):
      guard let scrum = state.scrums[id: id] else { return .none }
      state.selection = Identified(scrum, id: id)
      return .none

    case .setNavigation(selection: .none):
      state.selection = nil
      return .none
    }
  }
)

struct AppView: View {
  let store: Store<AppState, AppAction>

  @Environment(\.scenePhase) private var scenePhase

  struct ViewState: Equatable {
    let isAddingScrum: Bool
    let scrums: IdentifiedArrayOf<Scrum>
    let selectionId: Scrum.ID?

    init(state: AppState) {
      self.isAddingScrum = state.newScrum != nil
      self.scrums = state.scrums
      self.selectionId = state.selection?.id
    }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      List {
        ForEach(viewStore.scrums) { scrum in
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: \AppState.selection?.value,
                action: AppAction.scrum
              ),
              then: ScrumView.init(store:)
            ),
            tag: scrum.id,
            selection: viewStore.binding(
              get: \.selectionId,
              send: AppAction.setNavigation(selection:)
            )
          ) {
            CardView(scrum: scrum)
          }
          .listRowBackground(scrum.color)
        }
      }
      .navigationTitle("Daily Scrums")
      .navigationBarItems(
        trailing: Button(
          action: { viewStore.send(.setIsAddingScrum(true)) },
          label: { Image(systemName: "plus") }
        )
      )
      .sheet(
        isPresented: viewStore
          .binding(
            get: \.isAddingScrum,
            send: AppAction.setIsAddingScrum
          )
      ) {
        NavigationView {
          IfLetStore(
            self.store.scope(
              state: \AppState.newScrum,
              action: AppAction.newScrum
            ),
            then: EditView.init(store:)
          )
          .navigationBarItems(
            leading: Button("Dismiss") { viewStore.send(.setIsAddingScrum(false)) },
            trailing: Button("Add") { viewStore.send(.addNewScrum) }
          )
        }
      }
      .onChange(of: scenePhase) { viewStore.send(.scenePhaseChanged($0)) }
    }
  }
}

extension Scrum {
  init(id: UUID, state: EditState) {
    self.id = id
    self.title = state.title
    self.attendees = state.attendees
    self.lengthInMinutes = Int(state.lengthInMinutes)
    self.color = state.color
  }
}

extension IdentifiedArray where ID == Scrum.ID, Element == Scrum {
  static let mock: Self = [
    Scrum(
      attendees: ["Cathy", "Daisy", "Simon", "Jonathan"],
      color: .orange,
      lengthInMinutes: 10,
      title: "Design"
    ),
    Scrum(
      attendees: ["Katie", "Gray", "Euna", "Luis", "Darla"],
      color: .purple,
      lengthInMinutes: 5,
      title: "App Dev"
    ),
    Scrum(
      attendees: [
        "Chella",
        "Chris",
        "Christina",
        "Eden",
        "Karla",
        "Lindsey",
        "Aga",
        "Chad",
        "Jenn",
        "Sarah",
      ],
      color: .green,
      lengthInMinutes: 1,
      title: "Web Dev"
    ),
  ]
}
