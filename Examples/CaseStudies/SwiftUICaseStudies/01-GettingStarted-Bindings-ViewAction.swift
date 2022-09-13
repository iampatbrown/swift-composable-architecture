import ComposableArchitecture
import SwiftUI

private let readMe = """
This file demonstrates how to handle two-way bindings in the Composable Architecture using \
bindable state and actions.

Bindable state and actions allow you to safely eliminate the boilerplate caused by needing to \
have a unique action for every UI control. Instead, all UI bindings can be consolidated into a \
single `binding` action that holds onto a `BindingAction` value, and all bindable state can be \
safeguarded with the `BindableState` property wrapper.

It is instructive to compare this case study to the "Binding Basics" case study.
"""

struct BindingViewAction: ReducerProtocol {
  struct State: Equatable {
    @BindableState var sliderValue = 5.0
    @BindableState var stepCount = 10
    @BindableState var text = ""
    @BindableState var toggleIsOn = false
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case resetButtonTapped
  }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()
      .onChange(of: \.stepCount) { _, state, _ in
        state.sliderValue = .minimum(state.sliderValue, Double(state.stepCount))
        return .none
      }
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .resetButtonTapped:
        state = State()
        return .none
      }
    }
  }
}

struct BindingViewActionView: View {
  let store: StoreOf<BindingViewAction>

  struct ViewState: Equatable, Bindable {
    @BindableState var sliderValue: Double
    @BindableState var stepCount: Int
    @BindableState var text: String
    @BindableState var toggleIsOn: Bool

    init(state: BindingViewAction.State) {
      self.sliderValue = state.sliderValue
      self.stepCount = state.stepCount
      self.text = state.text
      self.toggleIsOn = state.toggleIsOn
    }

    func set(into state: inout BindingViewAction.State) {
      state.sliderValue = self.sliderValue
      state.stepCount = self.stepCount
      state.text = self.text
      state.toggleIsOn = self.toggleIsOn
    }
  }

  enum ViewAction: BindableAction {
    case binding(BindingAction<ViewState>)
    case resetButtonTapped
  }

  var body: some View {
    WithViewStore(
      self.store,
      observe: ViewState.init,
      send: BindingViewAction.Action.init
    ) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        HStack {
          TextField("Type here", text: viewStore.binding(\.$text))
            .disableAutocorrection(true)
            .foregroundStyle(viewStore.toggleIsOn ? Color.secondary : .primary)
          Text(alternate(viewStore.text))
        }
        .disabled(viewStore.toggleIsOn)

        Toggle(
          "Disable other controls",
          isOn: viewStore.binding(\.$toggleIsOn)
            .resignFirstResponder()
        )

        Stepper(
          "Max slider value: \(viewStore.stepCount)",
          value: viewStore.binding(\.$stepCount),
          in: 0...100
        )
        .disabled(viewStore.toggleIsOn)

        HStack {
          Text("Slider value: \(Int(viewStore.sliderValue))")

          Slider(value: viewStore.binding(\.$sliderValue), in: 0...Double(viewStore.stepCount))
            .tint(.accentColor)
        }
        .disabled(viewStore.toggleIsOn)

        Button("Reset") {
          viewStore.send(.resetButtonTapped)
        }
        .tint(.red)
      }
    }
    .monospacedDigit()
    .navigationTitle("Bindings form")
  }
}

extension BindingViewAction.Action {
  init(action: BindingViewActionView.ViewAction) {
    switch action {
    case .binding(let action):
      self = .binding(.pullback(action))
    case .resetButtonTapped:
      self = .resetButtonTapped
    }
  }
}

private func alternate(_ string: String) -> String {
  string
    .enumerated()
    .map { idx, char in
      idx.isMultiple(of: 2)
        ? char.uppercased()
        : char.lowercased()
    }
    .joined()
}

struct BindingViewActionView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      BindingViewActionView(
        store: Store(
          initialState: BindingViewAction.State(),
          reducer: BindingViewAction()
        )
      )
    }
  }
}
