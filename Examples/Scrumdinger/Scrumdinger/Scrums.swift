import ComposableArchitecture
import SwiftUI

struct Scrums: Equatable {
  var newScrum: NewScrum?
  var scrums: IdentifiedArrayOf<Scrum> = []

  init(_ scrums: [Scrum] = []) {
    self.scrums = .init(uniqueElements: scrums)
  }
}

enum ScrumsAction: Equatable {
  case newScrum(NewScrumAction)
  case scrum(id: Scrum.ID, action: ScrumAction)
  case setNewScrumSheet(isPresented: Bool)
}

struct ScrumsEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
  var uuid: () -> UUID
}

let scrumsReducer = Reducer<Scrums, ScrumsAction, ScrumsEnvironment>.combine(
  newScrumReducer
    .optional()
    .pullback(
      state: \Scrums.newScrum,
      action: /ScrumsAction.newScrum,
      environment: { _ in NewScrumEnvironment() }
    ),

  scrumReducer.forEach(
    state: \Scrums.scrums,
    action: /ScrumsAction.scrum(id:action:),
    environment: {
      ScrumEnvironment(
        audioPlayerClient: $0.audioPlayerClient,
        mainQueue: $0.mainQueue,
        speechClient: $0.speechClient
      )
    }
  ),

  Reducer { state, action, environment in
    switch action {
    case .newScrum(.addButtonTapped):
      if let newScrum = state.newScrum {
        let id = environment.uuid()
        state.scrums.append(Scrum(id: id, state: newScrum.state))
      }
      return Effect(value: .setNewScrumSheet(isPresented: false))

    case .newScrum(.cancelButtonTapped):
      return Effect(value: .setNewScrumSheet(isPresented: false))

    case .newScrum:
      return .none

    case .scrum:
      return .none

    case .setNewScrumSheet(isPresented: true):
      if state.newScrum == nil {
        state.newScrum = NewScrum()
      }
      return .none

    case .setNewScrumSheet(isPresented: false):
      state.newScrum = nil
      return .none
    }
  }
)

struct ScrumsView: View {
  let store: Store<Scrums, ScrumsAction>

  struct ViewState: Equatable {
    let isPresentingNewScrum: Bool

    init(state: Scrums) {
      self.isPresentingNewScrum = state.newScrum != nil
    }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      List {
        ForEachStore(
          self.store.scope(state: \Scrums.scrums, action: ScrumsAction.scrum(id:action:))
        ) { childStore in
          WithViewStore(childStore) { childViewStore in
            NavigationLink(
              destination: ScrumView(store: childStore)
            ) {
              CardView(scrum: childViewStore.state)
            }.listRowBackground(childViewStore.color)
          }
        }
      }
      .navigationTitle("Daily Scrums")
      .navigationBarItems(
        trailing: Button(
          action: { viewStore.send(.setNewScrumSheet(isPresented: true)) },
          label: { Image(systemName: "plus") }
        )
      )
      .sheet(
        isPresented: viewStore
          .binding(
            get: \.isPresentingNewScrum,
            send: ScrumsAction.setNewScrumSheet(isPresented:)
          )
      ) {
        NavigationView {
          IfLetStore(
            self.store.scope(
              state: \Scrums.newScrum,
              action: ScrumsAction.newScrum
            ),
            then: NewScrumView.init(store:)
          )
        }
      }
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
  static let placeholder: Self = [
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
