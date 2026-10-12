import Foundation

enum MenuChoice: Hashable {
    case preset(Preset)
    case custom(TimeInterval)

    var duration: TimeInterval? {
        switch self {
        case .preset(let preset): preset.duration
        case .custom(let duration): duration
        }
    }
}

struct DurationMenu {
    var rememberedCustom: TimeInterval?

    var choices: [MenuChoice] {
        let presets = Preset.allCases.map(MenuChoice.preset)
        guard let rememberedCustom, preset(lasting: rememberedCustom) == nil else { return presets }
        return presets + [.custom(rememberedCustom)]
    }

    mutating func choose(custom duration: TimeInterval) -> MenuChoice {
        if let preset = preset(lasting: duration) { return .preset(preset) }
        rememberedCustom = duration
        return .custom(duration)
    }

    private func preset(lasting duration: TimeInterval) -> Preset? {
        Preset.allCases.first { $0.duration == duration }
    }
}
