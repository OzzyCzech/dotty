import Foundation

struct DottyConfig {
    let destination: String

    static let defaultDestination = "~/.dotty/backup"

    static func empty() -> DottyConfig {
        DottyConfig(destination: defaultDestination)
    }

    static func load(from url: URL = Paths.configFile) -> DottyConfig {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty()
        }
        let destination = (json["destination"] as? String) ?? defaultDestination
        return DottyConfig(destination: destination)
    }
}
