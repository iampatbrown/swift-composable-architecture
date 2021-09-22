import ComposableArchitecture

extension FileClient {
  private static let fileName = "scrums.data"

  static var live: Self {
    let documentsFolder = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)
      .first!

    let fileURL = documentsFolder.appendingPathComponent(fileName)

    return Self(
      load: {
        Effect.catching { try Data(contentsOf: fileURL) }
          .decode(type: [ScrumData].self, decoder: JSONDecoder())
          .map { $0.map(Scrum.init) }
          .eraseToEffect()
      },
      save: { scrums in
        Effect.catching {
          let data = try JSONEncoder().encode(scrums.map(ScrumData.init))
          try data.write(to: fileURL)
        }.fireAndForget()
      }
    )
  }
}
