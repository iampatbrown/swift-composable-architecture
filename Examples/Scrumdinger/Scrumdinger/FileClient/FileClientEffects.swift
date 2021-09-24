import ComposableArchitecture

extension FileClient {
  func loadScrums() -> Effect<Result<[Scrum], NSError>, Never> {
    self.load([ScrumData].self, from: scrumsFileName)
      .map { $0.map { $0.map(Scrum.init) } }
      .eraseToEffect()
  }

  func saveScrums(_ scrums: [Scrum]) -> Effect<Never, Never> {
    self.save(scrums.map(ScrumData.init), to: scrumsFileName)
  }
}

private let scrumsFileName = "scrums.data"
