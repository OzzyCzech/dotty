import Foundation

#if canImport(Darwin)
import Darwin
#endif

enum Ansi {
    static let enabled: Bool = {
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
        return isatty(fileno(stdout)) != 0
    }()

    static func wrap(_ text: String, _ code: String) -> String {
        guard enabled else { return text }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    static func green(_ s: String) -> String { wrap(s, "32") }
    static func yellow(_ s: String) -> String { wrap(s, "33") }
    static func cyan(_ s: String) -> String { wrap(s, "36") }
    static func dim(_ s: String) -> String { wrap(s, "2") }
    static func bold(_ s: String) -> String { wrap(s, "1") }
    static func underline(_ s: String) -> String { wrap(s, "4") }
}
