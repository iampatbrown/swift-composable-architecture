import ComposableArchitecture

struct FileClient {
  var load: () -> Effect<[Scrum], Error>
  var save: ([Scrum]) -> Effect<Never, Error>
}
