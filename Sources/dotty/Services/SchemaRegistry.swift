import Foundation

final class SchemaRegistry {
    private(set) var schemas: [String: AppSchema] = [:]
    let config: DottyConfig

    init(config: DottyConfig = .load()) {
        self.config = config
        loadStandalones()
    }

    private func loadStandalones() {
        let fm = FileManager.default
        let dir = Paths.dottyDir
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        for url in entries where url.pathExtension == "json" {
            let id = url.deletingPathExtension().lastPathComponent.lowercased()
            if id == "config" { continue }
            guard let data = try? Data(contentsOf: url),
                  let schema = try? decoder.decode(AppSchema.self, from: data) else { continue }
            let withID = schema.with(id: id)
            if !validate(withID, sourceLabel: url.lastPathComponent) { continue }
            schemas[id] = withID
        }
    }

    private func validate(_ schema: AppSchema, sourceLabel: String) -> Bool {
        do {
            try schema.validate()
            return true
        } catch {
            FileHandle.standardError.write(Data("Invalid schema \(sourceLabel): \(error)\n".utf8))
            return false
        }
    }

    func find(_ id: String) -> AppSchema? {
        schemas[id.lowercased()]
    }

    func all() -> [AppSchema] {
        schemas.values.sorted { $0.id < $1.id }
    }

    func backupDir(for schema: AppSchema) -> URL {
        let base = schema.destination ?? config.destination
        return URL(fileURLWithPath: Paths.expand(base))
    }

    /// Reads bundled built-in schemas — used by `dotty init` to populate ~/.dotty/.
    static func bundledBuiltins() -> [AppSchema] {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        var result: [AppSchema] = []
        for url in urls {
            let id = url.deletingPathExtension().lastPathComponent.lowercased()
            guard let data = try? Data(contentsOf: url),
                  let schema = try? decoder.decode(AppSchema.self, from: data) else { continue }
            result.append(schema.with(id: id))
        }
        return result.sorted { $0.id < $1.id }
    }
}
