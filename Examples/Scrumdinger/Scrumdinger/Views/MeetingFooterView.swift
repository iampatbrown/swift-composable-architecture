import SwiftUI

struct MeetingFooterView: View {
  let speakers: [Meeting.Speaker]
  var skipAction: () -> Void
  private var speakerNumber: Int? {
    guard let index = speakers.firstIndex(where: { !$0.isCompleted }) else { return nil }
    return index + 1
  }

  private var isLastSpeaker: Bool {
    return speakers.dropLast().allSatisfy(\.isCompleted)
  }

  private var speakerText: String {
    guard let speakerNumber = speakerNumber else { return "No more speakers" }
    return "Speaker \(speakerNumber) of \(speakers.count)"
  }

  var body: some View {
    VStack {
      HStack {
        if isLastSpeaker {
          Text("Last Speaker")
        } else {
          Text(speakerText)
          Spacer()
          Button(action: skipAction) {
            Image(systemName: "forward.fill")
          }
          .accessibility(label: Text("Next speaker"))
        }
      }
    }
    .padding([.bottom, .horizontal])
  }
}

struct MeetingFooterView_Previews: PreviewProvider {
  static var speakers = [Meeting.Speaker(name: "Kim"), Meeting.Speaker(name: "Bill")]
  static var previews: some View {
    MeetingFooterView(speakers: speakers, skipAction: {})
      .previewLayout(.sizeThatFits)
  }
}
