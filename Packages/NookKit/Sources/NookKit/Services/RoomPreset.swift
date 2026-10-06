/// The suggested rooms in onboarding (O-02), each with a soft color and an SF Symbol chosen
/// for it (PRD §3). Colors are `RoomColor` raw values (NookUI).
public struct RoomPreset: Hashable, Sendable {
    public let name: String
    public let symbol: String
    public let colorKey: String

    public static let all: [RoomPreset] = [
        RoomPreset(name: "Kitchen", symbol: "fork.knife", colorKey: "butter"),
        RoomPreset(name: "Living room", symbol: "sofa", colorKey: "sage"),
        RoomPreset(name: "Bedroom", symbol: "bed.double", colorKey: "lavender"),
        RoomPreset(name: "Office", symbol: "desktopcomputer", colorKey: "sky"),
        RoomPreset(name: "Garage", symbol: "car", colorKey: "stone"),
        RoomPreset(name: "Bathroom", symbol: "shower", colorKey: "mint"),
        RoomPreset(name: "Dining room", symbol: "table.furniture", colorKey: "clay"),
        RoomPreset(name: "Kids’ room", symbol: "teddybear", colorKey: "rose"),
        RoomPreset(name: "Hallway", symbol: "door.left.hand.open", colorKey: "stone"),
        RoomPreset(name: "Laundry", symbol: "washer", colorKey: "sky"),
        RoomPreset(name: "Basement", symbol: "stairs", colorKey: "clay"),
        RoomPreset(name: "Attic", symbol: "house.lodge", colorKey: "butter"),
    ]

    /// The 8 room colors, in the order new custom rooms take them (03 §2.3).
    public static let colorKeys = ["clay", "sage", "sky", "lavender", "butter", "rose", "stone", "mint"]

    /// For a room the user names: its preset if the name matches one, otherwise a neutral
    /// symbol and the color the fewest rooms use.
    public static func style(for name: String, existingColorKeys: [String]) -> (symbol: String, colorKey: String) {
        if let preset = all.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return (preset.symbol, preset.colorKey)
        }
        let leastUsed = colorKeys.min { a, b in
            existingColorKeys.count(where: { $0 == a }) < existingColorKeys.count(where: { $0 == b })
        } ?? "stone"
        return ("square.grid.2x2", leastUsed)
    }
}
