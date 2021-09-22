import ComposableArchitecture
import SwiftUI

@main
struct ScrumdingerApp: App {
  let store = Store(
    initialState: AppState(),
    reducer: appReducer.debug(actionFormat: .labelsOnly),
    environment: AppEnvironment(
      audioPlayerClient: .live,
      backgroundQueue: DispatchQueue.global(qos: .background).eraseToAnyScheduler(),
      fileClient: .live,
      mainQueue: .main,
      speechClient: .live,
      uuid: UUID.init
    )
  )

  var body: some Scene {
    WindowGroup {
      NavigationView {
        AppView(store: store)
      }
      .navigationViewStyle(.stack)
      .onAppear { ViewStore(self.store).send(.onLaunch) }
    }
  }
}
