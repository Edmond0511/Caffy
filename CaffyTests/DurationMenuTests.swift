import Foundation
import Testing
@testable import Caffy

private let minute: TimeInterval = 60

struct DurationMenuTests {
    @Test func offersOnlyPresetsUntilACustomDurationIsUsed() {
        let menu = DurationMenu(rememberedCustom: nil)

        #expect(menu.choices == [.preset(.indefinitely), .preset(.minutes30), .preset(.hour1), .preset(.hours2)])
    }

    @Test func offersTheRememberedCustomDurationAfterThePresets() {
        let menu = DurationMenu(rememberedCustom: 45 * minute)

        #expect(menu.choices.last == .custom(45 * minute))
        #expect(menu.choices.count == 5)
    }

    @Test func doesNotDuplicateAPresetThatWasRemembered() {
        let menu = DurationMenu(rememberedCustom: 60 * minute)

        #expect(menu.choices == [.preset(.indefinitely), .preset(.minutes30), .preset(.hour1), .preset(.hours2)])
    }

    @Test func choosingACustomDurationRemembersIt() {
        var menu = DurationMenu(rememberedCustom: 45 * minute)

        let choice = menu.choose(custom: 90 * minute)

        #expect(choice == .custom(90 * minute))
        #expect(menu.rememberedCustom == 90 * minute)
    }

    @Test func choosingAPresetLengthSelectsThePresetInstead() {
        var menu = DurationMenu(rememberedCustom: 45 * minute)

        let choice = menu.choose(custom: 60 * minute)

        #expect(choice == .preset(.hour1))
        #expect(menu.rememberedCustom == 45 * minute)
    }
}
