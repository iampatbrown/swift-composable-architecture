import ComposableArchitecture
import SwiftUI

extension Color {
  static var random: Self {
    Self(
      .sRGB,
      red: .random(in: 0...1),
      green: .random(in: 0...1),
      blue: .random(in: 0...1),
      opacity: 1
    )
  }

  var components: (red: Double, green: Double, blue: Double, opacity: Double) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: CGFloat = 0
    UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
    return (red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(opacity))
  }

  var luminance: Double {
    let (red, green, blue, _) = components
    return red * 0.299 + green * 0.587 + blue * 0.114
  }

  var accessibleFontColor: Color { luminance > 0.5 ? .black : .white }
}

protocol LifecycleAction {
  static var onAppear: Self { get }
  static var onDisappear: Self { get }
}

extension Reducer where Action: LifecycleAction {
  func lifecycle(
    _ reducer: @escaping (inout State?, Action, Environment) -> Effect<Action, Never>
  ) -> Reducer<State?, Action, Environment> {
    .init { state, action, environment in
      let lifecycleEffects = reducer(&state, action, environment)
      guard state != nil else { return lifecycleEffects }
      let effects = self.run(&state!, action, environment)
      return .merge(lifecycleEffects, effects)
    }
  }
}
