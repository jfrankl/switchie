import Foundation
import AppKit

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags

    private static let allowedModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .capsLock, .function]

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = Self.normalize(modifiers: modifiers, keyCode: keyCode)
    }

    /// Strip non-allowed flags. Also remove `.function` when the key is itself
    /// a function key — fn is implicit then, and including it makes the
    /// displayed shortcut look like "fnF6" instead of "F6".
    private static func normalize(modifiers: NSEvent.ModifierFlags, keyCode: UInt32) -> NSEvent.ModifierFlags {
        var cleaned = modifiers.intersection(allowedModifierMask)
        if isFunctionKey(keyCode) { cleaned.remove(.function) }
        return cleaned
    }

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeyMap[keyCode] != nil
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiersRaw
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kc = try c.decode(UInt32.self, forKey: .keyCode)
        let raw = try c.decode(UInt.self, forKey: .modifiersRaw)
        self.keyCode = kc
        self.modifiers = Self.normalize(modifiers: NSEvent.ModifierFlags(rawValue: raw), keyCode: kc)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(keyCode, forKey: .keyCode)
        try c.encode(modifiers.rawValue, forKey: .modifiersRaw)
    }

    // MARK: - Display

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.function){ parts.append("fn") }
        parts.append(Self.keyString(for: keyCode) ?? "Key \(keyCode)")
        return parts.joined()
    }

    // MARK: - Default

    static let `default` = Shortcut(keyCode: 111, modifiers: [])

    // MARK: - Key Name Mapping

    static func keyString(for keyCode: UInt32) -> String? {
        if let fIdx = functionKeyMap[keyCode] { return "F\(fIdx)" }

        switch keyCode {
        case 36:  return "⏎"
        case 48:  return "⇥"
        case 49:  return "␣"
        case 51:  return "⌫"
        case 53:  return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:  break
        }

        return usKeyMap[keyCode]?.uppercased()
    }

    private static let functionKeyMap: [UInt32: Int] = [
        122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10, 103: 11, 111: 12
    ]

    private static let usKeyMap: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        50: "`"
    ]
}
