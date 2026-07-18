import SwiftUI

struct WeatherExpandedView: View {
    @ObservedObject private var manager = WeatherManager.shared
    @EnvironmentObject var appState: AppState
    @State private var hoveredAlertID: String?

    private func temp(_ celsius: Double) -> String {
        switch appState.temperatureUnit {
        case .celsius:    return "\(Int(celsius.rounded()))°C"
        case .fahrenheit: return "\(Int((celsius * 9 / 5 + 32).rounded()))°F"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current weather
            HStack(alignment: .top, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: manager.weather.conditionIcon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(temp(manager.weather.temperature))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(manager.weather.condition)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                if appState.currentState == .fullExpanded && shouldShowTopInsights {
                    topWeatherInsights
                        .frame(maxWidth: 420, alignment: .trailing)
                } else if let alert = manager.weather.alerts.first {
                    weatherAlertIcon(alert)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(
                        format: String(localized: "H:%@"),
                        locale: Locale.current,
                        temp(manager.weather.temperatureHigh)
                    ))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(
                        format: String(localized: "L:%@"),
                        locale: Locale.current,
                        temp(manager.weather.temperatureLow)
                    ))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Location
            if !manager.weather.locationName.isEmpty {
                Text(manager.weather.locationName)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            if !manager.weather.sourceName.isEmpty {
                Text(weatherSourceLabel)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
            }

            if appState.currentState != .fullExpanded, let status = meaningfulAlertStatus {
                weatherStatusRow(status)
            }

            if appState.currentState == .fullExpanded {
                Divider().background(.white.opacity(0.2))

                // Hourly forecast + details side by side
                HStack(alignment: .top, spacing: 0) {
                    // Hourly forecast (left)
                    if !manager.weather.hourlyForecast.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(manager.weather.hourlyForecast) { hour in
                                    VStack(spacing: 4) {
                                        Text(hour.hour)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.6))

                                        Image(systemName: hour.conditionIcon)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)

                                        Text(temp(hour.temperature))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 16)

                    // Weather details grid (right)
                    weatherDetailsGrid
                }
            }
        }
    }

    private var weatherDetailsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                weatherDetailCell(icon: "thermometer.medium", title: String(localized: "Feels Like"), value: temp(manager.weather.feelsLike))
                weatherDetailCell(icon: "humidity.fill", title: String(localized: "Humidity"), value: "\(manager.weather.humidity)%")
            }
            HStack(spacing: 16) {
                weatherDetailCell(icon: "wind", title: String(localized: "Wind"), value: windLabel)
                weatherDetailCell(icon: "sun.max.trianglebadge.exclamationmark.fill", title: String(localized: "UV Max"), value: uvLabel)
            }
        }
    }

    private var shouldShowTopInsights: Bool {
        manager.weather.alerts.first != nil ||
        meaningfulAlertStatus != nil ||
        hasAQIInfo
    }

    @ViewBuilder
    private var topWeatherInsights: some View {
        HStack(alignment: .center, spacing: 8) {
            if let alert = manager.weather.alerts.first {
                weatherAlertIcon(alert)
            } else if let status = meaningfulAlertStatus {
                weatherStatusRow(status)
            }

            if hasAQIInfo {
                topMetricPill(icon: "aqi.medium", title: String(localized: "AQI"), value: aqiLabel)
            }
        }
    }

    private var meaningfulAlertStatus: String? {
        let status = manager.weather.alertStatus
        guard !status.isEmpty, status != String(localized: "No active alerts") else {
            return nil
        }
        return status
    }

    private var hasAQIInfo: Bool {
        manager.weather.aqi != 0 || !manager.weather.aqiStatus.isEmpty
    }

    private func weatherDetailCell(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    private func weatherAlertIcon(_ alert: WeatherAlert) -> some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.orange)
            .frame(width: 30, height: 30)
            .background(Color.orange.opacity(0.14), in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .onHover { isHovering in
                hoveredAlertID = isHovering ? alert.id : nil
            }
            .popover(isPresented: Binding(
                get: { hoveredAlertID == alert.id },
                set: { isPresented in
                    if !isPresented {
                        hoveredAlertID = nil
                    }
                }
            )) {
                alertTooltip(alert)
            }
            .accessibilityLabel(alert.title)
    }

    private func weatherStatusRow(_ status: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(status)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white.opacity(0.45))
    }

    private func topMetricPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.42))
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.07), in: Capsule())
    }

    private func alertTooltip(_ alert: WeatherAlert) -> some View {
        WeatherAlertTooltipView(alert: alert)
    }

    private var weatherSourceLabel: String {
        if manager.weather.sourceDetail.isEmpty {
            return manager.weather.sourceName
        }
        return "\(manager.weather.sourceName) · \(manager.weather.sourceDetail)"
    }

    private var uvLabel: String {
        let uv = manager.weather.uvIndex
        let level: String
        switch uv {
        case ..<3: level = String(localized: "Low")
        case ..<6: level = String(localized: "Mod")
        case ..<8: level = String(localized: "High")
        case ..<11: level = String(localized: "Very High")
        default: level = String(localized: "Extreme")
        }
        return String(
            format: String(localized: "%lld %@"),
            locale: Locale.current,
            Int(uv),
            level
        )
    }

    private var aqiLabel: String {
        let aqi = manager.weather.aqi
        if aqi == 0 { return manager.weather.aqiStatus.isEmpty ? "—" : manager.weather.aqiStatus }
        if !manager.weather.aqiCategory.isEmpty {
            return String(
                format: String(localized: "%lld %@"),
                locale: Locale.current,
                aqi,
                manager.weather.aqiCategory
            )
        }

        let level: String
        switch aqi {
        case ..<51: level = String(localized: "Good")
        case ..<101: level = String(localized: "Moderate")
        case ..<151: level = String(localized: "Unhealthy*")
        case ..<201: level = String(localized: "Unhealthy")
        case ..<301: level = String(localized: "Very Poor")
        default: level = String(localized: "Hazardous")
        }
        return String(
            format: String(localized: "%lld %@"),
            locale: Locale.current,
            aqi,
            level
        )
    }

    private var windLabel: String {
        Measurement(value: manager.weather.windSpeed, unit: UnitSpeed.milesPerHour)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                )
            )
    }
}

struct WeatherAlertTooltipView: View {
    let alert: WeatherAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.top, 1)

                Text(alert.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !severityLabel.isEmpty {
                Text(severityLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
            }

            if !alert.detail.isEmpty {
                Text(alert.detail)
                    .font(.system(size: 12, weight: .medium))
                    .lineSpacing(2)
                    .foregroundColor(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 310, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 8)
        .padding(2)
    }

    private var severityLabel: String {
        let severity = alert.severity.trimmingCharacters(in: .whitespacesAndNewlines)
        switch severity.lowercased() {
        case "blue":
            return String(localized: "Blue Alert")
        case "yellow":
            return String(localized: "Yellow Alert")
        case "orange":
            return String(localized: "Orange Alert")
        case "red":
            return String(localized: "Red Alert")
        case "white":
            return String(localized: "White Alert")
        case "black":
            return String(localized: "Black Alert")
        default:
            return severity
        }
    }
}
