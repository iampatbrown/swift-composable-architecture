// NB: This file contains compile-time tests to ensure reducer builder generic inference is working.

import ComposableArchitecture
import OrderedCollections

private struct Root: ReducerProtocol {
  struct State {
    var feature: Feature.State
    var optionalFeature: Feature.State?
    var enumFeature: Features.State?
    var features: IdentifiedArrayOf<Feature.State>
    var moreFeatures: OrderedDictionary<Feature.State.ID, Feature.State>
    
    subscript(computedFeature id: Feature.State.ID) -> Feature.State? {
      get { features[id: id] }
      set { features[id: id] = newValue }
    }
  }

  enum Action {
    case feature(Feature.Action)
    case optionalFeature(Feature.Action)
    case enumFeature(Features.Action)
    case features(id: Feature.State.ID, feature: Feature.Action)
    case moreFeatures(id: Feature.State.ID, feature: Feature.Action)
    case computedFeatures(id: Feature.State.ID, feature: Feature.Action)
  }

  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      CombineReducers {
        Scope(state: \.feature, action: /Action.feature) {
          Feature()
          Feature()
        }
        Scope(state: \.feature, action: /Action.feature) {
          Feature()
          Feature()
        }
      }
      .ifLet(\.optionalFeature, action: /Action.optionalFeature) {
        Feature()
        Feature()
      }
      .ifLet(\.enumFeature, action: /Action.enumFeature) {
        EmptyReducer()
          .ifCaseLet(/Features.State.featureA, action: /Features.Action.featureA) {
            Feature()
            Feature()
          }
          .ifCaseLet(/Features.State.featureB, action: /Features.Action.featureB) {
            Feature()
            Feature()
          }

        Features()
      }
      .forEach(\State.features, action: /Action.features) {
        Feature()
        Feature()
      }
      .forEach(\State.moreFeatures, action: /Action.moreFeatures) {
        Feature()
        Feature()
      }
      .forEach(
        ids: \State.features.ids,
        state: { \State.[computedFeature: $0] },
        action: /Action.computedFeatures
      ) {
        Feature()
        Feature()
      }
    }

    @ReducerBuilder<State, Action>
    var testFlowControl: some ReducerProtocol<State, Action> {
      if true {
        Self()
      }

      if Bool.random() {
        Self()
      } else {
        EmptyReducer()
      }

      for _ in 1...10 {
        Self()
      }

      if #available(*) {
        Self()
      }
    }
  #else
    var body: Reduce<State, Action> {
      self.core
        .ifLet(\.optionalFeature, action: /Action.optionalFeature) {
          Feature()
          Feature()
        }
        .ifLet(\.enumFeature, action: /Action.enumFeature) {
          EmptyReducer()
            .ifCaseLet(/Features.State.featureA, action: /Features.Action.featureA) {
              Feature()
            }
            .ifCaseLet(/Features.State.featureB, action: /Features.Action.featureB) {
              Feature()
            }

          Features()
        }
        .forEach(\State.features, action: /Action.features) {
          Feature()
          Feature()
        }
        .forEach(\State.moreFeatures, action: /Action.moreFeatures) {
          Feature()
          Feature()
        }
        .forEach(
          ids: \State.features.ids,
          state: { \State.[computedFeature: $0] },
          action: /Action.computedFeatures
        ) {
          Feature()
          Feature()
        }
    }

    @ReducerBuilder<State, Action>
    var core: Reduce<State, Action> {
      CombineReducers {
        Scope(state: \.feature, action: /Action.feature) {
          Feature()
          Feature()
        }
        Scope(state: \.feature, action: /Action.feature) {
          Feature()
          Feature()
        }
      }
    }

    @ReducerBuilder<State, Action>
    var testFlowControl: Reduce<State, Action> {
      if true {
        Self()
      }

      if Bool.random() {
        Self()
      } else {
        EmptyReducer()
      }

      for _ in 1...10 {
        Self()
      }

      if #available(*) {
        Self()
      }
    }
  #endif

  struct Feature: ReducerProtocol {
    struct State: Identifiable {
      let id: Int
    }
    enum Action {
      case action
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      .none
    }
  }

  struct Features: ReducerProtocol {
    enum State {
      case featureA(Feature.State)
      case featureB(Feature.State)
    }

    enum Action {
      case featureA(Feature.Action)
      case featureB(Feature.Action)
    }

    #if swift(>=5.7)
      var body: some ReducerProtocol<State, Action> {
        Scope(state: /State.featureA, action: /Action.featureA) {
          Feature()
        }
        Scope(state: /State.featureB, action: /Action.featureB) {
          Feature()
        }
      }
    #else
      var body: Reduce<State, Action> {
        Scope(state: /State.featureA, action: /Action.featureA) {
          Feature()
        }
        Scope(state: /State.featureB, action: /Action.featureB) {
          Feature()
        }
      }
    #endif
  }
}
