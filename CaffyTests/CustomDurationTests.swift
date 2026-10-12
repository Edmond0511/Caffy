import Foundation
import Testing
@testable import Caffy

private let minute: TimeInterval = 60
private let hour: TimeInterval = 60 * minute

struct CustomDurationTests {
    @Test func bareNumberMeansMinutes() {
        #expect(CustomDuration.parse("45") == 45 * minute)
    }

    @Test func acceptsMinuteAndHourSuffixes() {
        #expect(CustomDuration.parse("90m") == 90 * minute)
        #expect(CustomDuration.parse("2h") == 2 * hour)
    }

    @Test(arguments: ["1h30", "1h 30m", "1:30"])
    func acceptsHoursAndMinutesTogether(text: String) {
        #expect(CustomDuration.parse(text) == hour + 30 * minute)
    }

    @Test func ignoresSurroundingSpacesAndCase() {
        #expect(CustomDuration.parse(" 2H ") == 2 * hour)
        #expect(CustomDuration.parse("1H30M") == hour + 30 * minute)
    }

    @Test(arguments: ["", "   ", "abc", "h", "1:75", "1.5h", "-5"])
    func rejectsUnreadableInput(text: String) {
        #expect(CustomDuration.parse(text) == nil)
    }

    @Test func acceptsOneMinuteUpToTwentyFourHours() {
        #expect(CustomDuration.parse("1") == minute)
        #expect(CustomDuration.parse("24h") == 24 * hour)
    }

    @Test(arguments: ["0", "0h0m", "24h1m", "1441", "99999999999999999999", "9999999999999999h"])
    func rejectsDurationsOutOfRange(text: String) {
        #expect(CustomDuration.parse(text) == nil)
    }
}

struct DurationTitleTests {
    @Test func namesMinutes() {
        #expect(durationTitle(minute) == "1 Minute")
        #expect(durationTitle(45 * minute) == "45 Minutes")
    }

    @Test func namesHoursAndLeavesOutZeroMinutes() {
        #expect(durationTitle(hour) == "1 Hour")
        #expect(durationTitle(3 * hour) == "3 Hours")
        #expect(durationTitle(hour + 30 * minute) == "1 Hour 30 Minutes")
        #expect(durationTitle(2 * hour + minute) == "2 Hours 1 Minute")
    }
}
