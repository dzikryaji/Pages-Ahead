import Foundation

struct ReadingPreferences: Equatable, Codable, Sendable {
    var weekdayPreferredTime = "Morning"
    var weekendPreferredTime = "Morning"
    var preferredWeather = "Cold"
    var preferencePriority = "Time"
    var preferredWindowMinutes = 30
    var personalizationEnabled = true
    var availableDays: Set<String> = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    var calendarAvailabilityEnabled = false
    var automaticLocation = true
    var preciseLocation = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case weekdayPreferredTime, weekendPreferredTime, preferredWeather, preferencePriority
        case preferredWindowMinutes, duration, preferredTime, weatherInfluence, temperature, place
        case personalizationEnabled, availableDays, calendarAvailabilityEnabled
        case automaticLocation, preciseLocation
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        preferredWindowMinutes = try values.decodeIfPresent(Int.self, forKey: .preferredWindowMinutes)
            ?? values.decodeIfPresent(Int.self, forKey: .duration)
            ?? 30
        let legacyPreferredTime = try values.decodeIfPresent(String.self, forKey: .preferredTime)
            ?? "Evening"
        let legacyWeatherInfluence = try values.decodeIfPresent(String.self, forKey: .weatherInfluence)
            ?? "Balanced"
        let legacyTemperature = try values.decodeIfPresent(String.self, forKey: .temperature)
            ?? "Mild"
        weekdayPreferredTime = try values.decodeIfPresent(String.self, forKey: .weekdayPreferredTime)
            ?? legacyPreferredTime
        weekendPreferredTime = try values.decodeIfPresent(String.self, forKey: .weekendPreferredTime)
            ?? legacyPreferredTime
        preferredWeather = try values.decodeIfPresent(String.self, forKey: .preferredWeather)
            ?? legacyTemperature
        if let storedPriority = try values.decodeIfPresent(String.self, forKey: .preferencePriority) {
            preferencePriority = storedPriority
        } else {
            preferencePriority = switch legacyWeatherInfluence {
            case "High": "Weather"
            case "Balanced": "Balanced"
            default: "Time"
            }
        }
        personalizationEnabled = try values.decodeIfPresent(Bool.self, forKey: .personalizationEnabled) ?? true
        availableDays = try values.decodeIfPresent(Set<String>.self, forKey: .availableDays)
            ?? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        calendarAvailabilityEnabled = try values.decodeIfPresent(Bool.self, forKey: .calendarAvailabilityEnabled) ?? false
        automaticLocation = try values.decodeIfPresent(Bool.self, forKey: .automaticLocation) ?? true
        preciseLocation = try values.decodeIfPresent(Bool.self, forKey: .preciseLocation) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(weekdayPreferredTime, forKey: .weekdayPreferredTime)
        try values.encode(weekendPreferredTime, forKey: .weekendPreferredTime)
        try values.encode(preferredWeather, forKey: .preferredWeather)
        try values.encode(preferencePriority, forKey: .preferencePriority)
        try values.encode(preferredWindowMinutes, forKey: .preferredWindowMinutes)
        try values.encode(personalizationEnabled, forKey: .personalizationEnabled)
        try values.encode(availableDays, forKey: .availableDays)
        try values.encode(calendarAvailabilityEnabled, forKey: .calendarAvailabilityEnabled)
        try values.encode(automaticLocation, forKey: .automaticLocation)
        try values.encode(preciseLocation, forKey: .preciseLocation)
    }
}
