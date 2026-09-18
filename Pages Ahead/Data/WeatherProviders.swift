import Foundation
import WeatherKit

struct WeatherForecastBatch: Codable, Sendable {
    let candidates: [HourlyWeatherSnapshot]
    let source: WeatherDataSource
}

enum WeatherProviderError: LocalizedError {
    case invalidResponse
    case noForecast

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Weather service returned an unexpected response."
        case .noForecast: "No upcoming weather data is available."
        }
    }
}

struct WeatherKitWeatherProvider: WeatherProviding {
    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        let hourly = try await WeatherService.shared.weather(for: coordinate.coreLocation, including: .hourly)
        let candidates = hourly.forecast.compactMap { hour -> HourlyWeatherSnapshot? in
            guard hour.date > .now else { return nil }
            return HourlyWeatherSnapshot(date: hour.date,
                                     temperature: Int(hour.temperature.converted(to: .celsius).value.rounded()),
                                     condition: hour.condition.description,
                                     symbolName: hour.symbolName)
        }
        guard !candidates.isEmpty else { throw WeatherProviderError.noForecast }
        return WeatherForecastBatch(candidates: candidates, source: .weatherKit)
    }
}

struct OpenMeteoWeatherProvider: WeatherProviding {
    private struct Response: Decodable { let hourly: Hourly }
    private struct Hourly: Decodable {
        let time: [TimeInterval]
        let temperature: [Double]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "forecast_hours", value: "168"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ]
        guard let url = components.url else { throw WeatherProviderError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("PagesAhead/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw WeatherProviderError.invalidResponse
        }
        return try decode(data)
    }

    func decode(_ data: Data, now: Date = .now) throws -> WeatherForecastBatch {
        let hourly = try JSONDecoder().decode(Response.self, from: data).hourly
        let count = min(hourly.time.count, hourly.temperature.count, hourly.weatherCode.count)
        let candidates = (0..<count).compactMap { index -> HourlyWeatherSnapshot? in
            let date = Date(timeIntervalSince1970: hourly.time[index])
            guard date > now else { return nil }
            let presentation = presentation(for: hourly.weatherCode[index])
            return HourlyWeatherSnapshot(date: date, temperature: Int(hourly.temperature[index].rounded()),
                                     condition: presentation.condition, symbolName: presentation.symbol)
        }
        guard !candidates.isEmpty else { throw WeatherProviderError.noForecast }
        return WeatherForecastBatch(candidates: candidates, source: .openMeteo)
    }

    private func presentation(for code: Int) -> (condition: String, symbol: String) {
        switch code {
        case 0: ("Clear", "sun.max.fill")
        case 1, 2: ("Partly cloudy", "cloud.sun.fill")
        case 3: ("Cloudy", "cloud.fill")
        case 45, 48: ("Foggy", "cloud.fog.fill")
        case 51...67, 80...82: ("Rain", "cloud.rain.fill")
        case 71...77, 85, 86: ("Snow", "cloud.snow.fill")
        case 95...99: ("Thunderstorms", "cloud.bolt.rain.fill")
        default: ("Variable", "cloud.sun.fill")
        }
    }
}

struct MockWeatherProvider: WeatherProviding {
    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        let conditions = [
            (24, "Light rain", "cloud.rain.fill"),
            (23, "Cloudy", "cloud.fill"),
            (26, "Clear", "sun.max.fill"),
            (25, "Partly cloudy", "cloud.sun.fill")
        ]
        let candidates = (1...168).compactMap { offset -> HourlyWeatherSnapshot? in
            guard let date = Calendar.current.date(byAdding: .hour, value: offset, to: .now) else { return nil }
            let condition = conditions[(offset / 6) % conditions.count]
            return HourlyWeatherSnapshot(date: date, temperature: condition.0, condition: condition.1, symbolName: condition.2)
        }
        return WeatherForecastBatch(candidates: candidates, source: .mock)
    }
}

struct FallbackWeatherProvider: WeatherProviding {
    let providers: [any WeatherProviding]

    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        for provider in providers {
            do {
                let forecast = try await provider.hourlyForecast(at: coordinate)
                if !forecast.candidates.isEmpty { return forecast }
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
        }
        throw WeatherProviderError.noForecast
    }
}
