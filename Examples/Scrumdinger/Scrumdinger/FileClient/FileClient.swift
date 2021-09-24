import ComposableArchitecture

struct FileClient {
  var delete: (String) -> Effect<Never, Error>
  var load: (String) -> Effect<Data, Error>
  var save: (String, Data) -> Effect<Never, Error>

  func load<A: Decodable>(
    _ type: A.Type, from fileName: String
  ) -> Effect<Result<A, NSError>, Never> {
    self.load(fileName)
      .decode(type: A.self, decoder: JSONDecoder())
      .mapError { $0 as NSError }
      .catchToEffect()
  }

  func save<A: Encodable>(
    _ data: A, to fileName: String
  ) -> Effect<Never, Never> {
    Effect.catching { try JSONEncoder().encode(data) }
      .flatMap { self.save($0, to: fileName) }
      .fireAndForget()
  }
}
