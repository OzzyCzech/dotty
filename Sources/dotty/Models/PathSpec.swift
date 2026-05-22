import Foundation

struct PathSpec: Equatable {
    let source: String
    let target: String?

    init(source: String, target: String? = nil) {
        self.source = source
        self.target = target
    }

    func resolvedTarget() -> String {
        target ?? Paths.relativeToBackupRoot(absolute: Paths.expand(source))
    }

    func validate() throws {
        guard let target else { return }
        if target.hasPrefix("/") || target.hasPrefix("~") {
            throw PathSpecError.absoluteTarget(target)
        }
        for component in target.split(separator: "/") {
            if component == ".." {
                throw PathSpecError.escapingTarget(target)
            }
        }
    }
}

enum PathSpecError: Error, CustomStringConvertible {
    case absoluteTarget(String)
    case escapingTarget(String)
    case duplicateTargets(String)

    var description: String {
        switch self {
        case .absoluteTarget(let t):
            return "target '\(t)' must be a relative path under the destination directory"
        case .escapingTarget(let t):
            return "target '\(t)' must not contain '..'"
        case .duplicateTargets(let t):
            return "duplicate target '\(t)' within schema"
        }
    }
}

extension PathSpec: Codable {
    enum CodingKeys: String, CodingKey {
        case source, target
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            self.source = str
            self.target = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try c.decode(String.self, forKey: .source)
        self.target = try? c.decode(String.self, forKey: .target)
    }

    func encode(to encoder: Encoder) throws {
        if target == nil {
            var c = encoder.singleValueContainer()
            try c.encode(source)
        } else {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(source, forKey: .source)
            if let target { try c.encode(target, forKey: .target) }
        }
    }
}
