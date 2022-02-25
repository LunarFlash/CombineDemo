import Combine
import SwiftUI

// Conforming to these means that the WeeklyWeatherViewModel‘s properties can be used as bindings
class WeeklyWeatherViewModel: ObservableObject, Identifiable {
  // The properly delegate @Published modifier makes it possible to observe the city property
  @Published var city: String = ""
  
  // Because the property is marked @Published, the compiler automatically synthesizes a publisher for it. SwiftUI subscribes to that publisher and redraws the screen when you change the property.
  @Published var dataSource: [DailyWeatherRowViewModel] = []
  
  private let weatherFetcher: WeatherFetchable
  
  // Think of disposables as a collection of references to requests. Without keeping these references, the network requests you’ll make won’t be kept alive, preventing you from getting responses from the server.
  private var disposables = Set<AnyCancellable>()
  
  // Add a scheduler parameter, so you can specify which queue the HTTP request will use.
  init(weatherFetcher: WeatherFetcher, scheduler: DispatchQueue = DispatchQueue(label: "WeatherViewModel")) {
    self.weatherFetcher = weatherFetcher
    // The city property uses the @Published property delegate so it acts like any other Publisher. This means it can be observed and can also make use of any other method that is available to Publisher.
    $city
    // $city emits its first value. Since the first value is an empty string, you need to skip it to avoid an unintended network call.
      .dropFirst(1)
    // Use debounce(for:scheduler:) to provide a better user experience. Without it the fetchWeather would make a new HTTP request for every letter typed. debounce works by waiting half a second (0.5) until the user stops typing and finally sending a value. You also pass scheduler as an argument, which means that any value emitted will be on that specific queue. Rule of thumb: You should process values on a background queue and deliver them on the main queue.
      .debounce(for: .seconds(0.5), scheduler: scheduler)
    // You observe these events via sink(receiveValue:) and handle them with fetchWeather(forCity:) that you previously implemented.
      .sink(receiveValue: fetchWeather(forCity:))
      .store(in: &disposables)
  }
  
  func fetchWeather(forCity city: String) {
    weatherFetcher.weeklyWeatherForecast(forCity: city)
      .map { response in
        response.list.map(DailyWeatherRowViewModel.init)
      }
      .map(Array.removeDuplicates)
      .receive(on: DispatchQueue.main)
    // Start the publisher via sink(receiveCompletion:receiveValue:). This is where you update dataSource accordingly. It’s important to notice that handling a completion — either a successful or failed one — happens separately from handling values.
      .sink(receiveCompletion: { [weak self] value in
        guard let self = self else { return}
        switch value {
        case .failure:
          self.dataSource = []
        case .finished:
          break
        }
      }, receiveValue: { [weak self] forecast in
        self?.dataSource = forecast
      })
      .store(in: &disposables)

  }
}

extension WeeklyWeatherViewModel {
  var currentWeatherView: some View {
    return WeeklyWeatherBuilder.makeCurrentWeatherView(withCity: city, weatherFetcher: weatherFetcher)
  }
}
