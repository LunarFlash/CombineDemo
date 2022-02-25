import SwiftUI

enum WeeklyWeatherBuilder {
  static func makeCurrentWeatherView(withCity city: String,
                                     weatherFetcher: WeatherFetchable) -> some View {
    let viewModel = CurrentWeatherViewModel(city: city, weatherFetcher: weatherFetcher)
    return CurrentWeatherView(viewModel: viewModel)
  }
}

