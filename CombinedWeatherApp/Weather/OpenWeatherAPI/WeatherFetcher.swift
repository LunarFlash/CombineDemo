import Foundation
import Combine

protocol WeatherFetchable {
  func weeklyWeatherForecast(forCity city: String) -> AnyPublisher<WeeklyForecastResponse, WeatherError>
  
  func currentWeatherForecast(forCity city: String) -> AnyPublisher<CurrentWeatherForecastResponse, WeatherError>
}

class WeatherFetcher {
  private let session: URLSession
  
  init(session: URLSession = .shared) {
    self.session = session
  }
}

// MARK: - OpenWeatherMap API
private extension WeatherFetcher {
  struct OpenWeatherAPI {
    static let scheme = "https"
    static let host = "api.openweathermap.org"
    static let path = "/data/2.5"
    static let key = "08ca48535e50aad481a1e0afa35ed5b1"
  }
  
  func makeWeeklyForecastComponents(
    withCity city: String
  ) -> URLComponents {
    var components = URLComponents()
    components.scheme = OpenWeatherAPI.scheme
    components.host = OpenWeatherAPI.host
    components.path = OpenWeatherAPI.path + "/forecast"
    
    components.queryItems = [
      URLQueryItem(name: "q", value: city),
      URLQueryItem(name: "mode", value: "json"),
      URLQueryItem(name: "units", value: "metric"),
      URLQueryItem(name: "APPID", value: OpenWeatherAPI.key)
    ]
    
    return components
  }
  
  func makeCurrentDayForecastComponents(
    withCity city: String
  ) -> URLComponents {
    var components = URLComponents()
    components.scheme = OpenWeatherAPI.scheme
    components.host = OpenWeatherAPI.host
    components.path = OpenWeatherAPI.path + "/weather"
    
    components.queryItems = [
      URLQueryItem(name: "q", value: city),
      URLQueryItem(name: "mode", value: "json"),
      URLQueryItem(name: "units", value: "metric"),
      URLQueryItem(name: "APPID", value: OpenWeatherAPI.key)
    ]
    
    return components
  }
}

extension WeatherFetcher: WeatherFetchable {
  func weeklyWeatherForecast(forCity city: String) -> AnyPublisher<WeeklyForecastResponse, WeatherError> {
    return forecast(with: makeWeeklyForecastComponents(withCity: city))
  }
  
  func currentWeatherForecast(forCity city: String) -> AnyPublisher<CurrentWeatherForecastResponse, WeatherError> {
    return forecast(with: makeCurrentDayForecastComponents(withCity: city))
  }
  
  private func forecast<T>(with components: URLComponents) -> AnyPublisher<T, WeatherError> where T: Decodable {
    // If this fails, return an error wrapped in a Fail value. Then, erase its type to AnyPublisher, since that’s the method’s return type.
    guard let url = components.url else {
      let error = WeatherError.network(description: "Couldn't create URL")
      return Fail(error: error).eraseToAnyPublisher()
    }
    // This method takes an instance of URLRequest and returns either a tuple (Data, URLResponse) or a URLError.
    return session.dataTaskPublisher(for: URLRequest(url: url))
      // Because the method returns AnyPublisher<T, WeatherError>, you map the error from URLError to WeatherError.
      .mapError { error in
        WeatherError.network(description: error.localizedDescription)
      }
    // The uses of flatMap deserves a post of their own. Here, you use it to convert the data coming from the server as JSON to a fully-fledged object. You use decode(_:) as an auxiliary function to achieve this. Since you are only interested in the first value emitted by the network request, you set .max(1).
      .flatMap(maxPublishers: .max(1)) { pair in
        decode(pair.data)
      }
    // If you don’t use eraseToAnyPublisher() you’ll have to carry over the full type returned by flatMap: Publishers.FlatMap<AnyPublisher<_, WeatherError>, Publishers.MapError<URLSession.DataTaskPublisher, WeatherError>>. As a consumer of the API, you don’t want to be burdened with these details. So, to improve the API ergonomics, you erase the type to AnyPublisher. This is also useful because adding any new transformation (e.g. filter) changes the returned type and, therefore, leaks implementation details.
      .eraseToAnyPublisher()
  }
}
