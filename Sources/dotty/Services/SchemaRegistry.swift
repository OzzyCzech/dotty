import Foundation

final class SchemaRegistry {
    private(set) var schemas: [String: AppSchema] = [:]
    private(set) var sources: [String: SchemaSource] = [:]
    let config: DottyConfig

    init(config: DottyConfig = .load()) {
        self.config = config
        loadBuiltins()
        applyConfigOverrides()
        loadStandalones()
    }

    private func loadBuiltins() {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            return
        }
        let decoder = JSONDecoder()
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let schema = try? decoder.decode(AppSchema.self, from: data) else { continue }
            let id = url.deletingPathExtension().lastPathComponent.lowercased()
            schemas[id] = schema.with(id: id)
            sources[id] = .builtin
        }
    }

    private func applyConfigOverrides() {
        for (id, override) in config.appOverrides {
            let existing = schemas[id]
            let name = override.name ?? existing?.name ?? id
            let paths = override.paths ?? existing?.paths ?? []
            let target = override.target ?? existing?.target
            guard !paths.isEmpty else { continue }
            schemas[id] = AppSchema(id: id, name: name, paths: paths, target: target)
            sources[id] = .config
        }
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
            schemas[id] = schema.with(id: id)
            sources[id] = .standalone
        }
    }

    func find(_ id: String) -> AppSchema? {
        schemas[id.lowercased()]
    }

    func all() -> [AppSchema] {
        schemas.values.sorted { $0.id < $1.id }
    }

    func source(of id: String) -> SchemaSource? {
        sources[id.lowercased()]
    }

    func backupDir(for schema: AppSchema) -> URL {
        let base = schema.target ?? config.destination
        return URL(fileURLWithPath: Paths.expand(base))
    }
}
