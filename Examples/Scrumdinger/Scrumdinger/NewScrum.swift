import ComposableArchitecture
import SwiftUI

struct NewScrum: Equatable {
  var state = EditState()
  // TODO: Add Cancel confirmationDialog
  // TODO: Possible validation eg. !title.isEmpty && !attendees.isEmpty
}

enum NewScrumAction: Equatable {
  case addButtonTapped
  case cancelButtonTapped
  case edit(EditAction)
}

struct NewScrumEnvironment {}

let newScrumReducer = Reducer<NewScrum, NewScrumAction, NewScrumEnvironment>.combine(
  editReducer.pullback(
    state: \NewScrum.state,
    action: /NewScrumAction.edit,
    environment: { _ in EditEnvironment() }
  ),
  Reducer { state, action, _ in
    switch action {
    case .addButtonTapped:
      return .none
    case .cancelButtonTapped:
      return .none
    case .edit:
      return .none
    }
  }
)

struct NewScrumView: View {
  let store: Store<NewScrum, NewScrumAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      EditView(
        store: store.scope(
          state: \NewScrum.state,
          action: NewScrumAction.edit
        )
      )
      .navigationBarItems(
        leading: Button("Cancel") { viewStore.send(.cancelButtonTapped) },
        trailing: Button("Add") { viewStore.send(.addButtonTapped) }
      )
    }
  }
}
