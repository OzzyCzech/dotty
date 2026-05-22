import Foundation

enum Confirmation {
    static func ask(_ prompt: String, defaultYes: Bool = false) -> Bool {
        let hint = defaultYes ? "[Y/n]" : "[y/N]"
        print("\(prompt) \(hint) ", terminator: "")
        guard let line = readLine() else { return defaultYes }
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return defaultYes }
        return trimmed == "y" || trimmed == "yes"
    }

    static func askText(_ prompt: String, default defaultValue: String) -> String {
        print("\(prompt) [\(defaultValue)]: ", terminator: "")
        guard let line = readLine() else { return defaultValue }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? defaultValue : trimmed
    }
}
