import Foundation

enum WeatherError: Error {
  case parsing(description: String)
  case network(description: String)
}
