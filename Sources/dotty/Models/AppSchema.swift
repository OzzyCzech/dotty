import Foundation

enum SchemaSource: String {
    case builtin
    case config
    case standalone
}

struct AppSchema: Codable, Equatable {
    let id: String
    let name: String
    let paths: [String]
    let target: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id, name, paths, target, category
    }

    init(id: String, name: String, paths: [String], target: String? = nil, category: String? = nil) {
        self.id = id
        self.name = name
        self.paths = paths
        self.target = target
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.name = try c.decode(String.self, forKey: .name)
        self.paths = try c.decode([String].self, forKey: .paths)
        self.target = try? c.decode(String.self, forKey: .target)
        self.category = try? c.decode(String.self, forKey: .category)
    }

    func with(id newID: String) -> AppSchema {
        AppSchema(id: newID, name: name, paths: paths, target: target, category: category)
    }
}

struct AppSchemaOverride: Codable {
    let paths: [String]?
    let target: String?
    let name: String?
}
