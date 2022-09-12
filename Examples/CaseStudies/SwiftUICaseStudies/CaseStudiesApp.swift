import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
//      RootView(
//        store: Store(
//          initialState: Root.State(),
//          reducer: Root()
//            .debug()
//            .signpost()
//        )
//      )
      TabView {
        BindingBasicsView(
          store: Store(
            initialState: BindingBasics.State(),
            reducer: BindingBasics()
              .debug()
          )
        )
        .tabItem { Text("Basics") }
        BindingViewStateView(
          store: Store(
            initialState: BindingViewState.State(),
            reducer: BindingViewState()
              .debug()
          )
        )
        .tabItem { Text("ViewState") }
        BindingViewActionView(
          store: Store(
            initialState: BindingViewAction.State(),
            reducer: BindingViewAction()
              .debug()
          )
        )
        .tabItem { Text("ViewAction") }
      }
    }
  }
}
