import Foundation

enum CustomDuration {
    // Longer than a day is what Indefinitely is for.
    static let range: ClosedRange<TimeInterval> = 60...(24 * 3600)

    static func parse(_ text: String) -> TimeInterval? {
        let text = text.trimmingCharacters(in: .whitespaces).lowercased()
        let parts: (hours: Substring?, minutes: Substring?)
        if let match = text.wholeMatch(of: /(\d+):([0-5]\d)/) {
            parts = (match.1, match.2)
        } else if let match = text.wholeMatch(of: /(?:(\d+)\s*h)?\s*(?:(\d+)\s*m?)?/) {
            parts = (match.1, match.2)
        } else {
            return nil
        }
        guard parts.hours != nil || parts.minutes != nil,
              let hours = Int(parts.hours ?? "0"),
              let minutes = Int(parts.minutes ?? "0")
        else { return nil }
        // In floating point so huge input can't overflow Int and crash.
        let duration = TimeInterval(hours) * 3600 + TimeInterval(minutes) * 60
        return range.contains(duration) ? duration : nil
    }
}

func durationTitle(_ duration: TimeInterval) -> String {
    let total = Int(duration / 60)
    let (hours, minutes) = (total / 60, total % 60)
    var parts: [String] = []
    if hours > 0 { parts.append("\(hours) \(hours == 1 ? "Hour" : "Hours")") }
    if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "Minute" : "Minutes")") }
    return parts.joined(separator: " ")
}
