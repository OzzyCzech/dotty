import Foundation

struct DottyConfig {
    let destination: String
    let appOverrides: [String: AppSchemaOverride]

    static let defaultDestination = "~/.dotty/backup"

    static func empty() -> DottyConfig {
        DottyConfig(destination: defaultDestination, appOverrides: [:])
    }

    static func load(from url: URL = Paths.configFile) -> DottyConfig {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty()
        }
        let destination = (json["destination"] as? String) ?? defaultDestination
        var overrides: [String: AppSchemaOverride] = [:]
        for (key, value) in json {
            if key == "destination" { continue }
            guard let dict = value as? [String: Any] else { continue }
            let paths = dict["paths"] as? [String]
            let target = dict["target"] as? String
            let name = dict["name"] as? String
            overrides[key.lowercased()] = AppSchemaOverride(paths: paths, target: target, name: name)
        }
        return DottyConfig(destination: destination, appOverrides: overrides)
    }
}
