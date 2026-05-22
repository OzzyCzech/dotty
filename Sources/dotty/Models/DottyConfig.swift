import Foundation

struct DottyConfig {
    let destination: String
    let appOverrides: [String: AppSchemaOverride]
    let disabledApps: Set<String>
    let enabledApps: Set<String>?

    static let defaultDestination = "~/.dotty/backup"

    static func empty() -> DottyConfig {
        DottyConfig(destination: defaultDestination, appOverrides: [:], disabledApps: [], enabledApps: nil)
    }

    static func load(from url: URL = Paths.configFile) -> DottyConfig {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty()
        }
        let destination = (json["destination"] as? String) ?? defaultDestination
        let enabledRaw = json["enabled"] as? [String]
        let enabled: Set<String>? = enabledRaw.map { Set($0.map { $0.lowercased() }) }
        let disabled: Set<String> = enabled != nil
            ? []
            : Set((json["disabled"] as? [String] ?? []).map { $0.lowercased() })
        var overrides: [String: AppSchemaOverride] = [:]
        let decoder = JSONDecoder()
        for (key, value) in json {
            if key == "destination" || key == "disabled" || key == "enabled" { continue }
            guard let dict = value as? [String: Any] else { continue }
            let paths: [PathSpec]?
            if let raw = dict["paths"], let data = try? JSONSerialization.data(withJSONObject: raw) {
                paths = try? decoder.decode([PathSpec].self, from: data)
            } else {
                paths = nil
            }
            let target = dict["target"] as? String
            let name = dict["name"] as? String
            let mode = (dict["mode"] as? String).flatMap { SyncMode(rawValue: $0) }
            overrides[key.lowercased()] = AppSchemaOverride(paths: paths, target: target, name: name, mode: mode)
        }
        return DottyConfig(destination: destination, appOverrides: overrides, disabledApps: disabled, enabledApps: enabled)
    }
}
