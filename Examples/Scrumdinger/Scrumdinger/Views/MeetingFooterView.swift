import ComposableArchitecture
import SwiftUI

struct MeetingFooterView: View {
  let store: Store<Meeting, MeetingAction>

  struct ViewState: Equatable {
    let speakers: [Meeting.Speaker]

    init(state: Meeting) {
      self.speakers = state.speakers
    }

    var speakerNumber: Int? { speakers.firstIndex(where: { !$0.isCompleted }).map { $0 + 1 } }
    var isLastSpeaker: Bool { speakers.dropLast().allSatisfy(\.isCompleted) }
    var speakerText: String { speakerNumber.map { "Speaker \($0) of \(speakers.count)" } ?? "No more speakers" }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      VStack {
        HStack {
          if viewStore.isLastSpeaker {
            Text("Last Speaker")
          } else {
            Text(viewStore.speakerText)
            Spacer()
            Button(action: { viewStore.send(.skipSpeaker) }) {
              Image(systemName: "forward.fill")
            }
            .accessibility(label: Text("Next speaker"))
          }
        }
      }
      .padding([.bottom, .horizontal])
    }
  }
}
