import Foundation

/// Shared helpers used by `dotty init` and `dotty reinit` for picker UI and
/// schema-file IO. Pure helpers — no command-specific orchestration.
enum SchemaSetup {
    static func loadExistingSchemaIDs() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: Paths.dottyDir, includingPropertiesForKeys: nil) else { return [] }
        return entries
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
            .filter { $0 != "config" }
    }

    static func writeSchema(_ schema: AppSchema, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        struct Payload: Codable {
            let name: String
            let category: String?
            let destination: String?
            let paths: [PathSpec]
        }
        let payload = Payload(name: schema.name, category: schema.category, destination: schema.destination, paths: schema.paths)
        let data = try encoder.encode(payload)
        try data.write(to: url)
    }

    /// Writes a minimal placeholder schema for `id` so the user has a starting
    /// point to edit. Tries to guess a sensible default path from the id.
    static func writeBlankSchema(id: String, to url: URL) throws {
        let name = id.prefix(1).uppercased() + id.dropFirst()
        let payload: [String: Any] = [
            "name": name,
            "category": "Other",
            "paths": ["~/.\(id)"]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }

    static func writeRootConfig(destination: String) throws {
        let payload: [String: Any] = ["destination": destination]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: Paths.configFile)
    }

    static func buildPickerRows(_ schemas: [AppSchema]) -> [PickerRow] {
        let grouped = Dictionary(grouping: schemas) { $0.category ?? "Other" }
        let ordered = ListCommand.categoryOrder.filter { grouped[$0] != nil }
            + grouped.keys.filter { !ListCommand.categoryOrder.contains($0) }.sorted()
        let maxID = schemas.map { $0.id.count }.max() ?? 0
        var rows: [PickerRow] = []
        for category in ordered {
            guard let entries = grouped[category] else { continue }
            rows.append(.header(category))
            for schema in entries.sorted(by: { $0.id < $1.id }) {
                let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
                rows.append(.item(id: schema.id, label: schema.id + pad, secondary: schema.name))
            }
        }
        return rows
    }

    static func printGrouped(_ schemas: [AppSchema]) {
        let grouped = Dictionary(grouping: schemas) { $0.category ?? "Other" }
        let ordered = ListCommand.categoryOrder.filter { grouped[$0] != nil }
            + grouped.keys.filter { !ListCommand.categoryOrder.contains($0) }.sorted()
        let maxID = schemas.map { $0.id.count }.max() ?? 0
        for category in ordered {
            guard let entries = grouped[category] else { continue }
            print()
            print(Ansi.bold(Ansi.underline(category)))
            for schema in entries.sorted(by: { $0.id < $1.id }) {
                let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
                print("  \(Ansi.green("●")) \(schema.id)\(pad)  \(Ansi.dim(schema.name))")
            }
        }
    }
}
