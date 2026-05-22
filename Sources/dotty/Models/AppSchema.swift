import Foundation

struct AppSchema: Codable, Equatable {
    let id: String
    let name: String
    let paths: [PathSpec]
    let destination: String?
    let category: String?
    let strategy: SyncStrategy?

    enum CodingKeys: String, CodingKey {
        case id, name, paths, destination, category, strategy
    }

    init(id: String, name: String, paths: [PathSpec], destination: String? = nil, category: String? = nil, strategy: SyncStrategy? = nil) {
        self.id = id
        self.name = name
        self.paths = paths
        self.destination = destination
        self.category = category
        self.strategy = strategy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.name = try c.decode(String.self, forKey: .name)
        self.paths = try c.decode([PathSpec].self, forKey: .paths)
        self.destination = try? c.decode(String.self, forKey: .destination)
        self.category = try? c.decode(String.self, forKey: .category)
        self.strategy = try? c.decode(SyncStrategy.self, forKey: .strategy)
    }

    func with(id newID: String) -> AppSchema {
        AppSchema(id: newID, name: name, paths: paths, destination: destination, category: category, strategy: strategy)
    }

    func validate() throws {
        var seen = Set<String>()
        for spec in paths {
            try spec.validate()
            let resolved = spec.resolvedTarget()
            if !seen.insert(resolved).inserted {
                throw PathSpecError.duplicateTargets(resolved)
            }
        }
    }

    func hasLinkPaths() -> Bool {
        paths.contains { $0.resolvedStrategy(default: strategy) == .link }
    }

    func hasCopyPaths() -> Bool {
        paths.contains { $0.resolvedStrategy(default: strategy) == .copy }
    }
}
