import Foundation
import CoreLocation
import Combine
import CryptoKit

struct WeatherData {
    var temperature: Double = 0
    var temperatureHigh: Double = 0
    var temperatureLow: Double = 0
    var condition: String = String(localized: "Sunny")
    var conditionIcon: String = "sun.max.fill"
    var locationName: String = ""
    var hourlyForecast: [HourlyWeather] = []
    var feelsLike: Double = 0
    var humidity: Int = 0
    var windSpeed: Double = 0
    var uvIndex: Double = 0
    var aqi: Int = 0
    var aqiCategory: String = ""
    var aqiStatus: String = ""
    var sourceName: String = ""
    var sourceDetail: String = ""
    var alerts: [WeatherAlert] = []
    var alertStatus: String = ""
}

struct HourlyWeather: Identifiable {
    let id = UUID()
    let hour: String
    let temperature: Double
    let conditionIcon: String
}

struct WeatherAlert: Identifiable {
    let id: String
    let title: String
    let severity: String
    let detail: String
}

private struct QWeatherConfiguration {
    let host: String
    let token: String
}

private struct CaiyunConfiguration {
    let appKey: String
    let appSecret: String
    let legacyToken: String
}

final class WeatherManager: NSObject, ObservableObject {
    static let shared = WeatherManager()

    @Published var weather = WeatherData()
    @Published var isLoading = false

    private let locationManager = CLLocationManager()
    private var lastFetchTime: Date?
    private var lastFetchSignature: String?
    private var refreshToken: ModuleRefreshToken?

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        requestLocationAndFetch()
        registerRefresh()
    }

    // MARK: - Location

    func requestLocationAndFetch() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorized:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            // locationManagerDidChangeAuthorization will call startUpdatingLocation() once granted
        default:
            break
        }
    }

    // MARK: - Fetching

    func fetchWeather(latitude: Double, longitude: Double) {
        guard !isLoading else { return }

        // Debounce: don't fetch more than once per 5 minutes
        let preference = Self.preferredWeatherDataSource()
        let signature = fetchSignature(latitude: latitude, longitude: longitude, preference: preference)
        if let lastFetch = lastFetchTime,
           lastFetchSignature == signature,
           Date().timeIntervalSince(lastFetch) < 300 {
            return
        }

        isLoading = true

        let location = CLLocation(latitude: latitude, longitude: longitude)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let placemark = placemarks?.first
            let isMainlandChina = Self.isMainlandChina(
                isoCountryCode: placemark?.isoCountryCode,
                latitude: latitude,
                longitude: longitude
            )
            DispatchQueue.main.async {
                if let city = placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea {
                    self.weather.locationName = city
                }
            }

            let source = Self.resolvedSource(
                preference: preference,
                isMainlandChina: isMainlandChina,
                qweatherConfigured: Self.qweatherConfiguration() != nil,
                caiyunConfigured: Self.caiyunConfiguration() != nil
            )

            switch source {
            case .qweather:
                if let configuration = Self.qweatherConfiguration() {
                    self.fetchQWeather(latitude: latitude, longitude: longitude, configuration: configuration, signature: signature)
                } else {
                    self.fetchOpenMeteo(latitude: latitude, longitude: longitude, signature: signature)
                }
            case .caiyun:
                if let configuration = Self.caiyunConfiguration() {
                    self.fetchCaiyun(latitude: latitude, longitude: longitude, configuration: configuration, signature: signature)
                } else {
                    self.fetchOpenMeteo(latitude: latitude, longitude: longitude, signature: signature)
                }
            case .auto, .openMeteo:
                self.fetchOpenMeteo(latitude: latitude, longitude: longitude, signature: signature)
            }
        }
    }

    func refreshIgnoringCache() {
        lastFetchTime = nil
        lastFetchSignature = nil
        requestLocationAndFetch()
    }

    static func resolvedSource(
        preference: WeatherDataSource,
        isMainlandChina: Bool,
        qweatherConfigured: Bool,
        caiyunConfigured: Bool
    ) -> WeatherDataSource {
        switch preference {
        case .auto:
            return isMainlandChina && qweatherConfigured ? .qweather : .openMeteo
        case .qweather:
            return qweatherConfigured ? .qweather : .openMeteo
        case .caiyun:
            return caiyunConfigured ? .caiyun : .openMeteo
        case .openMeteo:
            return .openMeteo
        }
    }

    static func isMainlandChina(isoCountryCode: String?, latitude: Double, longitude: Double) -> Bool {
        if let isoCountryCode {
            return isoCountryCode.uppercased() == "CN"
        }

        return (18.0...54.0).contains(latitude) && (73.0...135.0).contains(longitude)
    }

    private func fetchOpenMeteo(latitude: Double, longitude: Double, signature: String) {
        markSource(name: "Open-Meteo", detail: String(localized: "Global fallback"))

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,uv_index_max&wind_speed_unit=mph&timezone=auto&forecast_days=1"

        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }

            guard let data, error == nil else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.parseOpenMeteoWeatherResponse(json)
                        self?.lastFetchTime = Date()
                        self?.lastFetchSignature = signature
                    }
                }
            } catch {
                print("Weather parse error: \(error)")
            }
        }.resume()

        // Fetch AQI from Open-Meteo Air Quality API
        let aqiURLString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=us_aqi"
        if let aqiURL = URL(string: aqiURLString) {
            URLSession.shared.dataTask(with: aqiURL) { [weak self] data, _, error in
                guard let data, error == nil else { return }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let current = json["current"] as? [String: Any],
                       let aqi = current["us_aqi"] as? Int {
                        DispatchQueue.main.async {
                            self?.weather.aqi = aqi
                            self?.weather.aqiCategory = String(localized: "US AQI")
                        }
                    }
                } catch {
                    print("AQI parse error: \(error)")
                }
            }.resume()
        }

    }

    private func fetchQWeather(
        latitude: Double,
        longitude: Double,
        configuration: QWeatherConfiguration,
        signature: String
    ) {
        markSource(name: String(localized: "QWeather"), detail: "")

        let group = DispatchGroup()
        let location = String(format: "%.2f,%.2f", longitude, latitude)
        let query = qweatherQueryItems([
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "lang", value: Self.qweatherLanguage)
        ], configuration: configuration)
        var didReceiveCurrentConditions = false

        if let url = qweatherURL(path: "/v7/weather/now", queryItems: query, configuration: configuration) {
            group.enter()
            fetchJSON(url: url, headers: qweatherHeaders(configuration: configuration)) { [weak self] json in
                DispatchQueue.main.async {
                    if let json {
                        didReceiveCurrentConditions = self?.parseQWeatherNowResponse(json) == true
                    }
                    group.leave()
                }
            }
        }

        if let url = qweatherURL(path: "/v7/weather/3d", queryItems: query, configuration: configuration) {
            group.enter()
            fetchJSON(url: url, headers: qweatherHeaders(configuration: configuration)) { [weak self] json in
                DispatchQueue.main.async {
                    if let json {
                        self?.parseQWeatherDailyResponse(json)
                    }
                    group.leave()
                }
            }
        }

        if let url = qweatherURL(path: "/v7/weather/24h", queryItems: query, configuration: configuration) {
            group.enter()
            fetchJSON(url: url, headers: qweatherHeaders(configuration: configuration)) { [weak self] json in
                DispatchQueue.main.async {
                    if let json {
                        self?.parseQWeatherHourlyResponse(json)
                    }
                    group.leave()
                }
            }
        }

        let qweatherLatitude = String(format: "%.2f", latitude)
        let qweatherLongitude = String(format: "%.2f", longitude)
        let airPath = "/airquality/v1/current/\(qweatherLatitude)/\(qweatherLongitude)"
        let airQuery = [URLQueryItem(name: "lang", value: Self.qweatherLanguage)]
        if let url = qweatherURL(path: airPath, queryItems: airQuery, configuration: configuration) {
            group.enter()
            fetchJSONResult(url: url, headers: qweatherHeaders(configuration: configuration)) { [weak self] json, failure in
                DispatchQueue.main.async {
                    if let json {
                        if self?.parseQWeatherAirResponse(json) != true {
                            self?.weather.aqiStatus = Self.qweatherFailureMessage(
                                from: json,
                                fallback: failure ?? String(localized: "AQI unavailable")
                            )
                        }
                    } else if let failure {
                        self?.weather.aqiStatus = failure
                    }
                    group.leave()
                }
            }
        }

        let warningPath = "/weatheralert/v1/current/\(qweatherLatitude)/\(qweatherLongitude)"
        let warningQuery = [
            URLQueryItem(name: "localTime", value: "false"),
            URLQueryItem(name: "lang", value: Self.qweatherLanguage)
        ]
        if let url = qweatherURL(path: warningPath, queryItems: warningQuery, configuration: configuration) {
            group.enter()
            fetchJSONResult(url: url, headers: qweatherHeaders(configuration: configuration)) { [weak self] json, failure in
                DispatchQueue.main.async {
                    if let json {
                        if self?.parseQWeatherWarningResponse(json) != true {
                            self?.weather.alertStatus = Self.qweatherFailureMessage(
                                from: json,
                                fallback: failure ?? String(localized: "Alerts unavailable")
                            )
                        }
                    } else if let failure {
                        self?.weather.alertStatus = failure
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard didReceiveCurrentConditions else {
                self?.fetchOpenMeteo(latitude: latitude, longitude: longitude, signature: signature)
                return
            }
            self?.lastFetchTime = Date()
            self?.lastFetchSignature = signature
            self?.isLoading = false
        }
    }

    private func fetchCaiyun(
        latitude: Double,
        longitude: Double,
        configuration: CaiyunConfiguration,
        signature: String
    ) {
        markSource(name: String(localized: "Caiyun Weather"), detail: "")

        guard let request = caiyunRequest(latitude: latitude, longitude: longitude, configuration: configuration) else {
            isLoading = false
            return
        }

        fetchJSON(request: request) { [weak self] json in
            DispatchQueue.main.async {
                guard let json else {
                    self?.fetchOpenMeteo(latitude: latitude, longitude: longitude, signature: signature)
                    return
                }

                let didReceiveCurrentConditions = self?.parseCaiyunResponse(json) == true
                if didReceiveCurrentConditions {
                    self?.lastFetchTime = Date()
                    self?.lastFetchSignature = signature
                } else {
                    self?.fetchOpenMeteo(latitude: latitude, longitude: longitude, signature: signature)
                    return
                }
                self?.isLoading = false
            }
        }
    }

    // MARK: - Parsing

    private func parseOpenMeteoWeatherResponse(_ json: [String: Any]) {
        // Current weather
        if let current = json["current"] as? [String: Any] {
            if let temp = current["temperature_2m"] as? Double {
                weather.temperature = temp
            }
            if let code = current["weather_code"] as? Int {
                weather.condition = conditionName(for: code)
                weather.conditionIcon = conditionIcon(for: code)
            }
            if let feelsLike = current["apparent_temperature"] as? Double {
                weather.feelsLike = feelsLike
            }
            if let humidity = current["relative_humidity_2m"] as? Int {
                weather.humidity = humidity
            }
            if let wind = current["wind_speed_10m"] as? Double {
                weather.windSpeed = wind
            }
        }

        // Daily high/low + UV
        if let daily = json["daily"] as? [String: Any] {
            if let maxTemps = daily["temperature_2m_max"] as? [Double], let first = maxTemps.first {
                weather.temperatureHigh = first
            }
            if let minTemps = daily["temperature_2m_min"] as? [Double], let first = minTemps.first {
                weather.temperatureLow = first
            }
            if let uvMax = daily["uv_index_max"] as? [Double], let first = uvMax.first {
                weather.uvIndex = first
            }
        }

        // Hourly forecast (next 6 hours)
        if let hourly = json["hourly"] as? [String: Any],
           let times = hourly["time"] as? [String],
           let temps = hourly["temperature_2m"] as? [Double],
           let codes = hourly["weather_code"] as? [Int] {

            let calendar = Foundation.Calendar.current
            let currentHour = calendar.component(.hour, from: Date())
            let startIndex = max(currentHour, 0)
            let endIndex = min(startIndex + 6, times.count)

            var forecast: [HourlyWeather] = []
            for i in startIndex..<endIndex {
                let hourStr: String
                if i == currentHour {
                    hourStr = String(localized: "Now")
                } else {
                    hourStr = localizedHourLabel(for: times[i], fallbackHour: i % 24)
                }

                forecast.append(HourlyWeather(
                    hour: hourStr,
                    temperature: temps[i],
                    conditionIcon: conditionIcon(for: codes[i])
                ))
            }
            weather.hourlyForecast = forecast
        }
    }

    private func parseQWeatherNowResponse(_ json: [String: Any]) -> Bool {
        guard (json["code"] as? String) == "200",
              let now = json["now"] as? [String: Any] else { return false }

        if let temp = Self.doubleValue(now["temp"]) {
            weather.temperature = temp
        }
        if let text = now["text"] as? String, !text.isEmpty {
            weather.condition = text
        }
        if let icon = now["icon"] as? String {
            weather.conditionIcon = qweatherIcon(for: icon)
        }
        if let feelsLike = Self.doubleValue(now["feelsLike"]) {
            weather.feelsLike = feelsLike
        }
        if let humidity = Self.intValue(now["humidity"]) {
            weather.humidity = humidity
        }
        if let wind = Self.doubleValue(now["windSpeed"]) {
            weather.windSpeed = wind * 0.621371
        }
        return true
    }

    private func parseQWeatherDailyResponse(_ json: [String: Any]) {
        guard (json["code"] as? String) == "200",
              let daily = json["daily"] as? [[String: Any]],
              let today = daily.first else { return }

        if let high = Self.doubleValue(today["tempMax"]) {
            weather.temperatureHigh = high
        }
        if let low = Self.doubleValue(today["tempMin"]) {
            weather.temperatureLow = low
        }
        if let uv = Self.doubleValue(today["uvIndex"]) {
            weather.uvIndex = uv
        }
    }

    private func parseQWeatherHourlyResponse(_ json: [String: Any]) {
        guard (json["code"] as? String) == "200",
              let hourly = json["hourly"] as? [[String: Any]] else { return }

        weather.hourlyForecast = hourly.prefix(6).enumerated().compactMap { index, hour in
            guard let temp = Self.doubleValue(hour["temp"]) else { return nil }
            let label = index == 0
                ? String(localized: "Now")
                : localizedISOHourLabel(for: hour["fxTime"] as? String, fallbackHour: index)
            return HourlyWeather(
                hour: label,
                temperature: temp,
                conditionIcon: qweatherIcon(for: hour["icon"] as? String ?? "")
            )
        }
    }

    private func parseQWeatherAirResponse(_ json: [String: Any]) -> Bool {
        if let indexes = json["indexes"] as? [[String: Any]] {
            let preferredIndex = Self.preferredQWeatherAQIIndex(from: indexes)

            guard let preferredIndex else { return false }
            if let aqi = Self.intValue(preferredIndex["aqi"]) {
                weather.aqi = aqi
            } else if let display = preferredIndex["aqiDisplay"] as? String,
                      let aqi = Self.intValue(display) {
                weather.aqi = aqi
            } else {
                return false
            }
            weather.aqiCategory = preferredIndex["category"] as? String ?? ""
            weather.aqiStatus = ""
            return true
        }

        return false
    }

    private func parseQWeatherWarningResponse(_ json: [String: Any]) -> Bool {
        if let metadata = json["metadata"] as? [String: Any],
           metadata["zeroResult"] as? Bool == true {
            weather.alerts = []
            weather.alertStatus = String(localized: "No active alerts")
            return true
        }

        if let alerts = json["alerts"] as? [[String: Any]] {
            weather.alerts = alerts.compactMap { item in
                let eventType = item["eventType"] as? [String: Any]
                let title = (item["headline"] as? String)
                    ?? (eventType?["name"] as? String)
                    ?? ""
                guard !title.isEmpty else { return nil }
                let color = item["color"] as? [String: Any]
                let severity = (color?["code"] as? String)
                    ?? (item["severity"] as? String)
                    ?? ""
                let detail = (item["description"] as? String)
                    ?? (item["instruction"] as? String)
                    ?? ""
                return WeatherAlert(id: item["id"] as? String ?? title, title: title, severity: severity, detail: detail)
            }
            weather.alertStatus = weather.alerts.isEmpty ? String(localized: "No active alerts") : ""
            return true
        }

        return false
    }

    private func parseCaiyunResponse(_ json: [String: Any]) -> Bool {
        guard let result = json["result"] as? [String: Any] else { return false }
        var didReceiveCurrentConditions = false

        if let realtime = result["realtime"] as? [String: Any] {
            if let temp = Self.doubleValue(realtime["temperature"]) {
                weather.temperature = temp
                didReceiveCurrentConditions = true
            }
            if let apparent = Self.doubleValue(realtime["apparent_temperature"]) {
                weather.feelsLike = apparent
            }
            if let humidity = Self.doubleValue(realtime["humidity"]) {
                weather.humidity = Int((humidity * 100).rounded())
            }
            if let skycon = realtime["skycon"] as? String {
                weather.condition = caiyunConditionName(for: skycon)
                weather.conditionIcon = caiyunIcon(for: skycon)
            }
            if let wind = realtime["wind"] as? [String: Any],
               let speed = Self.doubleValue(wind["speed"]) {
                weather.windSpeed = speed * 0.621371
            }
            if let lifeIndex = realtime["life_index"] as? [String: Any],
               let ultraviolet = lifeIndex["ultraviolet"] as? [String: Any],
               let uv = Self.doubleValue(ultraviolet["index"]) {
                weather.uvIndex = uv
            }
            if let airQuality = realtime["air_quality"] as? [String: Any],
               let aqi = airQuality["aqi"] as? [String: Any],
               let chinaAQI = Self.intValue(aqi["chn"]) {
                weather.aqi = chinaAQI
                if let description = airQuality["description"] as? [String: Any] {
                    weather.aqiCategory = description["chn"] as? String ?? ""
                }
            }
        }

        if let daily = result["daily"] as? [String: Any],
           let temperatures = daily["temperature"] as? [[String: Any]],
           let today = temperatures.first {
            if let high = Self.doubleValue(today["max"]) {
                weather.temperatureHigh = high
            }
            if let low = Self.doubleValue(today["min"]) {
                weather.temperatureLow = low
            }
        }

        if let hourly = result["hourly"] as? [String: Any],
           let temperatures = hourly["temperature"] as? [[String: Any]] {
            let skycons = hourly["skycon"] as? [[String: Any]] ?? []
            weather.hourlyForecast = temperatures.prefix(6).enumerated().compactMap { index, item in
                guard let temp = Self.doubleValue(item["value"]) else { return nil }
                let skycon = skycons.indices.contains(index) ? skycons[index]["value"] as? String : nil
                let label = index == 0
                    ? String(localized: "Now")
                    : localizedISOHourLabel(for: item["datetime"] as? String, fallbackHour: index)
                return HourlyWeather(
                    hour: label,
                    temperature: temp,
                    conditionIcon: caiyunIcon(for: skycon ?? "")
                )
            }
        }

        if let alert = result["alert"] as? [String: Any],
           let content = alert["content"] as? [[String: Any]] {
            weather.alerts = content.compactMap { item in
                let title = (item["title"] as? String) ?? ""
                guard !title.isEmpty else { return nil }
                let detail = (item["description"] as? String) ?? ""
                let severity = (item["status"] as? String) ?? ""
                return WeatherAlert(id: title, title: title, severity: severity, detail: detail)
            }
        }
        return didReceiveCurrentConditions
    }

    // MARK: - WMO Weather Code Mapping

    private func conditionName(for code: Int) -> String {
        switch code {
        case 0: return String(localized: "Sunny")
        case 1, 2, 3: return String(localized: "Partly Cloudy")
        case 45, 48: return String(localized: "Foggy")
        case 51, 53, 55: return String(localized: "Drizzle")
        case 61, 63, 65: return String(localized: "Rain")
        case 66, 67: return String(localized: "Freezing Rain")
        case 71, 73, 75: return String(localized: "Snow")
        case 77: return String(localized: "Snow Grains")
        case 80, 81, 82: return String(localized: "Showers")
        case 85, 86: return String(localized: "Snow Showers")
        case 95: return String(localized: "Thunderstorm")
        case 96, 99: return String(localized: "Hailstorm")
        default: return String(localized: "Sunny")
        }
    }

    private func localizedHourLabel(for timestamp: String, fallbackHour: Int) -> String {
        if let date = Self.hourTimestampFormatter.date(from: timestamp) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        var components = DateComponents()
        components.calendar = .current
        components.hour = fallbackHour
        components.minute = 0
        if let fallbackDate = components.date {
            return fallbackDate.formatted(date: .omitted, time: .shortened)
        }

        return "\(fallbackHour)"
    }

    private static let hourTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    private func conditionIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "sun.max.fill"
        }
    }

    private func qweatherIcon(for code: String) -> String {
        guard let value = Int(code) else { return "cloud.sun.fill" }
        switch value {
        case 100, 150: return "sun.max.fill"
        case 101...103, 151...153: return "cloud.sun.fill"
        case 104, 154: return "cloud.fill"
        case 300...399: return "cloud.rain.fill"
        case 400...499: return "cloud.snow.fill"
        case 500...515: return "cloud.fog.fill"
        case 900: return "thermometer.sun.fill"
        case 901: return "thermometer.snowflake"
        default: return "cloud.sun.fill"
        }
    }

    private func caiyunIcon(for skycon: String) -> String {
        switch skycon {
        case "CLEAR_DAY": return "sun.max.fill"
        case "CLEAR_NIGHT": return "moon.stars.fill"
        case "PARTLY_CLOUDY_DAY": return "cloud.sun.fill"
        case "PARTLY_CLOUDY_NIGHT": return "cloud.moon.fill"
        case "CLOUDY": return "cloud.fill"
        case "LIGHT_HAZE", "MODERATE_HAZE", "HEAVY_HAZE", "FOG": return "cloud.fog.fill"
        case "LIGHT_RAIN", "MODERATE_RAIN", "HEAVY_RAIN", "STORM_RAIN": return "cloud.rain.fill"
        case "LIGHT_SNOW", "MODERATE_SNOW", "HEAVY_SNOW", "STORM_SNOW": return "cloud.snow.fill"
        case "DUST", "SAND": return "sun.dust.fill"
        case "WIND": return "wind"
        default: return "cloud.sun.fill"
        }
    }

    private func caiyunConditionName(for skycon: String) -> String {
        switch skycon {
        case "CLEAR_DAY", "CLEAR_NIGHT": return String(localized: "Sunny")
        case "PARTLY_CLOUDY_DAY", "PARTLY_CLOUDY_NIGHT": return String(localized: "Partly Cloudy")
        case "CLOUDY": return String(localized: "Cloudy")
        case "FOG": return String(localized: "Foggy")
        case "LIGHT_RAIN", "MODERATE_RAIN", "HEAVY_RAIN", "STORM_RAIN": return String(localized: "Rain")
        case "LIGHT_SNOW", "MODERATE_SNOW", "HEAVY_SNOW", "STORM_SNOW": return String(localized: "Snow")
        case "LIGHT_HAZE", "MODERATE_HAZE", "HEAVY_HAZE": return String(localized: "Haze")
        case "DUST", "SAND": return String(localized: "Dust")
        case "WIND": return String(localized: "Wind")
        default: return String(localized: "Partly Cloudy")
        }
    }

    private func localizedISOHourLabel(for timestamp: String?, fallbackHour: Int) -> String {
        if let timestamp {
            if let date = Self.providerTimestampFormatter.date(from: timestamp) ?? Self.isoTimestampFormatter.date(from: timestamp) {
                return date.formatted(date: .omitted, time: .shortened)
            }
        }

        return localizedHourLabel(for: "", fallbackHour: Foundation.Calendar.current.component(.hour, from: Date()) + fallbackHour)
    }

    private static let providerTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mmXXXXX"
        return formatter
    }()

    private static let isoTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func fetchJSON(
        url: URL,
        headers: [String: String] = [:],
        completion: @escaping ([String: Any]?) -> Void
    ) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        fetchJSON(request: request, completion: completion)
    }

    private func fetchJSON(
        request: URLRequest,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data, error == nil else {
                completion(nil)
                return
            }

            do {
                completion(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            } catch {
                print("Weather JSON parse error: \(error)")
                completion(nil)
            }
        }.resume()
    }

    private func fetchJSONResult(
        url: URL,
        headers: [String: String] = [:],
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(nil, String(localized: "Network unavailable"))
                return
            }

            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
                completion(json, "HTTP \(status)")
                return
            }

            guard let json else {
                completion(nil, String(localized: "Invalid response"))
                return
            }

            completion(json, nil)
        }.resume()
    }

    private func qweatherURL(
        path: String,
        queryItems: [URLQueryItem],
        configuration: QWeatherConfiguration
    ) -> URL? {
        var components = URLComponents()
        if configuration.host.contains("://"),
           let hostComponents = URLComponents(string: configuration.host) {
            components.scheme = hostComponents.scheme
            components.host = hostComponents.host
        } else {
            components.scheme = "https"
            components.host = configuration.host
        }
        components.path = path
        components.queryItems = queryItems
        return components.url
    }

    private func qweatherHeaders(configuration: QWeatherConfiguration) -> [String: String] {
        ["Authorization": "Bearer \(configuration.token)"]
    }

    private func qweatherQueryItems(
        _ queryItems: [URLQueryItem],
        configuration: QWeatherConfiguration
    ) -> [URLQueryItem] {
        queryItems
    }

    private func caiyunRequest(
        latitude: Double,
        longitude: Double,
        configuration: CaiyunConfiguration
    ) -> URLRequest? {
        let coordinate = String(format: "%.4f,%.4f", longitude, latitude)
        let credential = configuration.appKey.isEmpty ? configuration.legacyToken : configuration.appKey
        let path = "/v2.6/\(credential)/\(coordinate)/weather"
        let query = [
            "alert": "true",
            "dailysteps": "1",
            "hourlysteps": "6"
        ]
        let queryString = Self.encodedQueryString(query)
        guard let url = URL(string: "https://api.caiyunapp.com\(path)?\(queryString)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !configuration.appKey.isEmpty, !configuration.appSecret.isEmpty {
            let nonce = UUID().uuidString
            let timestamp = String(Int(Date().timeIntervalSince1970))
            let stringToSign = ["GET", path, queryString, configuration.appKey, nonce, timestamp].joined(separator: ":")
            let signature = Self.caiyunSignature(for: stringToSign, appSecret: configuration.appSecret)
            request.setValue(nonce, forHTTPHeaderField: "x-cy-nonce")
            request.setValue(timestamp, forHTTPHeaderField: "x-cy-timestamp")
            request.setValue(signature, forHTTPHeaderField: "x-cy-signature")
        }

        return request
    }

    private func markSource(name: String, detail: String) {
        DispatchQueue.main.async { [weak self] in
            self?.weather.sourceName = name
            self?.weather.sourceDetail = detail
            self?.weather.alerts = []
            self?.weather.aqiCategory = ""
            self?.weather.aqiStatus = ""
            self?.weather.alertStatus = ""
        }
    }

    private func fetchSignature(latitude: Double, longitude: Double, preference: WeatherDataSource) -> String {
        [
            String(format: "%.3f", latitude),
            String(format: "%.3f", longitude),
            preference.rawValue,
            Self.qweatherConfiguration() == nil ? "q0" : "q1",
            Self.caiyunConfiguration() == nil ? "c0" : "c1"
        ].joined(separator: ":")
    }

    private static func preferredWeatherDataSource() -> WeatherDataSource {
        let rawValue = UserDefaults.standard.string(forKey: "module.weather.dataSource") ?? WeatherDataSource.auto.rawValue
        return WeatherDataSource(rawValue: rawValue) ?? .auto
    }

    private static var qweatherLanguage: String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh" : "en"
    }

    private static func qweatherConfiguration() -> QWeatherConfiguration? {
        let defaults = UserDefaults.standard
        let env = ProcessInfo.processInfo.environment
        let host = (defaults.string(forKey: "module.weather.qweatherHost") ?? env["SUPERISLAND_QWEATHER_HOST"] ?? "devapi.qweather.com")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let credentialID = (defaults.string(forKey: "module.weather.qweatherCredentialID")
            ?? env["SUPERISLAND_QWEATHER_CREDENTIAL_ID"]
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let projectID = (defaults.string(forKey: "module.weather.qweatherProjectID")
            ?? env["SUPERISLAND_QWEATHER_PROJECT_ID"]
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKey = (defaults.string(forKey: "module.weather.qweatherPrivateKey")
            ?? env["SUPERISLAND_QWEATHER_PRIVATE_KEY"]
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token = Self.qweatherJWT(
            credentialID: credentialID,
            projectID: projectID,
            privateKeyInput: privateKey
        ) else {
            return nil
        }
        return QWeatherConfiguration(host: host.isEmpty ? "devapi.qweather.com" : host, token: token)
    }

    static func qweatherJWT(
        credentialID: String,
        projectID: String,
        privateKeyInput: String,
        issuedAt: Date = Date()
    ) -> String? {
        let credentialID = credentialID.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectID = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credentialID.isEmpty,
              !projectID.isEmpty,
              let privateKey = qweatherPrivateKey(from: privateKeyInput) else {
            return nil
        }

        let issuedAtSeconds = Int(issuedAt.timeIntervalSince1970) - 30
        let header: [String: Any] = [
            "alg": "EdDSA",
            "kid": credentialID
        ]
        let payload: [String: Any] = [
            "sub": projectID,
            "iat": issuedAtSeconds,
            "exp": issuedAtSeconds + 3600
        ]

        guard let headerData = try? JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }

        let signingInput = "\(base64URL(headerData)).\(base64URL(payloadData))"
        guard let signature = try? privateKey.signature(for: Data(signingInput.utf8)) else {
            return nil
        }
        return "\(signingInput).\(base64URL(signature))"
    }

    static func qweatherPrivateKey(from input: String) -> Curve25519.Signing.PrivateKey? {
        guard let rawRepresentation = qweatherPrivateKeyRawRepresentation(from: input) else {
            return nil
        }
        return try? Curve25519.Signing.PrivateKey(rawRepresentation: rawRepresentation)
    }

    static func qweatherPrivateKeyRawRepresentation(from input: String) -> Data? {
        let text = resolvedQWeatherPrivateKeyText(from: input)
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if text.count == 64,
           text.allSatisfy({ $0.isHexDigit }),
           let hexData = dataFromHexString(text),
           hexData.count == 32 {
            return hexData
        }

        let base64Text: String
        if text.contains("BEGIN") {
            base64Text = text
                .components(separatedBy: "-----")
                .filter { !$0.contains("BEGIN") && !$0.contains("END") }
                .joined()
                .split(whereSeparator: { $0.isWhitespace })
                .joined()
        } else {
            base64Text = text
                .split(whereSeparator: { $0.isWhitespace })
                .joined()
        }

        guard let decoded = base64DecodedData(base64Text) else { return nil }
        if decoded.count == 32 {
            return decoded
        }
        return ed25519SeedFromPKCS8DER(decoded)
    }

    private static func resolvedQWeatherPrivateKeyText(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let candidatePath: String
        if trimmed.hasPrefix("file://"), let url = URL(string: trimmed) {
            candidatePath = url.path
        } else if trimmed.hasPrefix("~/") {
            candidatePath = NSString(string: trimmed).expandingTildeInPath
        } else {
            candidatePath = trimmed
        }

        if FileManager.default.fileExists(atPath: candidatePath),
           let fileText = try? String(contentsOfFile: candidatePath, encoding: .utf8) {
            return fileText
        }
        return input
    }

    private static func ed25519SeedFromPKCS8DER(_ data: Data) -> Data? {
        let oid = Data([0x06, 0x03, 0x2B, 0x65, 0x70])
        guard let oidRange = data.range(of: oid) else { return nil }
        let tail = data[oidRange.upperBound...]

        let nestedOctetString = Data([0x04, 0x22, 0x04, 0x20])
        if let range = tail.range(of: nestedOctetString) {
            let start = range.upperBound
            let end = start + 32
            guard end <= data.endIndex else { return nil }
            return data[start..<end]
        }

        let octetString = Data([0x04, 0x20])
        if let range = tail.range(of: octetString) {
            let start = range.upperBound
            let end = start + 32
            guard end <= data.endIndex else { return nil }
            return data[start..<end]
        }

        return nil
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64DecodedData(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }

    private static func dataFromHexString(_ value: String) -> Data? {
        var data = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    static func preferredQWeatherAQIIndex(from indexes: [[String: Any]]) -> [String: Any]? {
        let localChinaIndex = indexes.first { item in
            let code = (item["code"] as? String ?? "").lowercased()
            let name = (item["name"] as? String ?? "").lowercased()
            return code.contains("cn")
                || code.contains("china")
                || code.contains("mee")
                || name.contains("china")
                || name.contains("中国")
        }
        if let localChinaIndex {
            return localChinaIndex
        }

        return indexes.first { item in
            (item["code"] as? String ?? "").lowercased() != "qaqi"
        } ?? indexes.first
    }

    private static func qweatherFailureMessage(from json: [String: Any], fallback: String) -> String {
        if let error = json["error"] as? [String: Any] {
            if let status = error["status"] {
                let title = error["title"] as? String
                if let title, !title.isEmpty {
                    return "QWeather \(status) \(title)"
                }
                return "QWeather \(status)"
            }
            if let detail = error["detail"] as? String, !detail.isEmpty {
                return detail
            }
        }
        if let code = json["code"] as? String, !code.isEmpty {
            return "QWeather \(code)"
        }
        if let status = json["status"] as? String, !status.isEmpty {
            return status
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return fallback
    }

    private static func caiyunConfiguration() -> CaiyunConfiguration? {
        let defaults = UserDefaults.standard
        let env = ProcessInfo.processInfo.environment
        let appKey = (defaults.string(forKey: "module.weather.caiyunAppKey")
            ?? env["SUPERISLAND_CAIYUN_APP_KEY"]
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let appSecret = (defaults.string(forKey: "module.weather.caiyunAppSecret")
            ?? env["SUPERISLAND_CAIYUN_APP_SECRET"]
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyToken = (defaults.string(forKey: "module.weather.caiyunToken")
            ?? env["SUPERISLAND_CAIYUN_TOKEN"]
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!appKey.isEmpty && !appSecret.isEmpty) || !legacyToken.isEmpty else {
            return nil
        }
        return CaiyunConfiguration(appKey: appKey, appSecret: appSecret, legacyToken: legacyToken)
    }

    static func encodedQueryString(_ query: [String: String]) -> String {
        query.keys.sorted().map { key in
            "\(urlFormEncoded(key))=\(urlFormEncoded(query[key] ?? ""))"
        }.joined(separator: "&")
    }

    private static func urlFormEncoded(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        return value
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? value
    }

    static func caiyunSignature(for stringToSign: String, appSecret: String) -> String {
        let key = SymmetricKey(data: Data(appSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        return Data(signature)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value.rounded()) }
        if let value = value as? String { return Int(value) ?? Double(value).map { Int($0.rounded()) } }
        return nil
    }

    // MARK: - Refresh

    private func registerRefresh() {
        Task { @MainActor [weak self] in
            self?.refreshToken = ModuleRefreshScheduler.shared.register(
                id: "weather.refresh",
                name: "Weather refresh",
                module: .builtIn(.weather),
                policy: .visibleOnly(Constants.weatherRefreshInterval, tolerance: 300),
                enabled: { AppState.shared.weatherEnabled }
            ) { [weak self] in
                self?.requestLocationAndFetch()
            }
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in
            ModuleRefreshScheduler.shared.unregister(token)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        manager.stopUpdatingLocation()
        fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("SuperIsland: location error — \(error.localizedDescription), status=\(locationManager.authorizationStatus.rawValue)")
    }
}
