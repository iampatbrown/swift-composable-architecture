import ComposableArchitecture
import SwiftUI

struct MeetingHeaderView: View {
  let store: Store<Meeting, MeetingAction>

  struct ViewState: Equatable {
    let secondsElapsed: Int
    let secondsRemaining: Int
    let scrumColor: Color

    init(state: Meeting) {
      self.secondsElapsed = state.secondsElapsed
      self.secondsRemaining = state.secondsRemaining
      self.scrumColor = state.scrumColor
    }

    var progress: Double {
      guard secondsRemaining > 0 else { return 1 }
      let totalSeconds = Double(secondsElapsed + secondsRemaining)
      return Double(secondsElapsed) / totalSeconds
    }

    var minutesRemaining: Int { secondsRemaining / 60 }
    var minutesRemainingMetric: String { minutesRemaining == 1 ? "minute" : "minutes" }
  }

  var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init).actionless) { viewStore in
      VStack {
        ProgressView(value: viewStore.progress)
          .progressViewStyle(ScrumProgressViewStyle(scrumColor: viewStore.scrumColor))
        HStack {
          VStack(alignment: .leading) {
            Text("Seconds Elapsed")
              .font(.caption)
            Label("\(viewStore.secondsElapsed)", systemImage: "hourglass.bottomhalf.fill")
          }
          Spacer()
          VStack(alignment: .trailing) {
            Text("Seconds Remaining")
              .font(.caption)
            HStack {
              Text("\(viewStore.secondsRemaining)")
              Image(systemName: "hourglass.tophalf.fill")
            }
          }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Time remaining"))
      .accessibilityValue(Text("\(viewStore.minutesRemaining) \(viewStore.minutesRemainingMetric)"))
      .padding([.top, .horizontal])
    }
  }

  struct ScrumProgressViewStyle: ProgressViewStyle {
    var scrumColor: Color

    func makeBody(configuration: Configuration) -> some View {
      ZStack {
        RoundedRectangle(cornerRadius: 10.0)
          .fill(scrumColor.accessibleFontColor)
          .frame(height: 20.0)
        ProgressView(configuration)
          .frame(height: 12.0)
          .padding(.horizontal)
      }
    }
  }
}
