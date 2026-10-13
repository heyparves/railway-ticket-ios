import Foundation

extension Int {
    /// "৳1,450"
    var taka: String { "৳" + formatted(.number) }
    /// Spoken form for VoiceOver, e.g. "1,450 taka".
    var takaSpoken: String { "\(formatted(.number)) taka" }
}

extension Date {
    var timeText: String { formatted(date: .omitted, time: .shortened) }
    var dayText: String { formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    var longDayText: String { formatted(.dateTime.weekday(.wide).day().month(.wide).year()) }
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}

extension TimeInterval {
    /// "5h 20m"
    var durationText: String {
        let minutes = Int(self / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    var durationSpoken: String {
        Duration.seconds(self).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
}

enum Validation {
    static func isEmail(_ value: String) -> Bool {
        value.range(of: #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }

    /// Bangladeshi mobile number: 01[3-9] followed by 8 digits.
    static func isMobile(_ value: String) -> Bool {
        value.range(of: #"^01[3-9]\d{8}$"#, options: .regularExpression) != nil
    }

    static func isName(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces).count >= 2
    }

    static let minimumPasswordLength = 8

    static func isCardNumber(_ value: String) -> Bool {
        let digits = value.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count), digits.count == value.filter({ !$0.isWhitespace }).count else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, item in
            let (index, digit) = item
            guard index.isMultiple(of: 2) == false else { return total + digit }
            let doubled = digit * 2
            return total + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum.isMultiple(of: 10)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// "01712345678" -> "0171*****678"
    var maskedPhone: String {
        guard count == 11 else { return self }
        return prefix(4) + String(repeating: "•", count: 4) + suffix(3)
    }
}
