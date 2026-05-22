import ArgumentParser
import Foundation

struct SchemasCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schemas",
        abstract: "Browse the bundled schemas that `dotty add` and `dotty init` can use."
    )

    @Argument(help: "Optional app identifier — prints that schema's JSON.")
    var app: String?

    @Flag(name: [.short, .long], help: "Compact one-line list of identifiers.")
    var compact: Bool = false

    func run() throws {
        let bundled = SchemaRegistry.bundledBuiltins()

        if let app {
            let id = app.lowercased()
            guard let schema = bundled.first(where: { $0.id == id }) else {
                FileHandle.standardError.write(Data("No bundled schema for '\(id)'.\n".utf8))
                throw ExitCode(1)
            }
            try printSchema(schema)
            return
        }

        if compact {
            print(bundled.map { $0.id }.joined(separator: " "))
            return
        }

        let grouped = Dictionary(grouping: bundled) { $0.category ?? "Other" }
        let known = ListCommand.categoryOrder.filter { grouped[$0] != nil }
        let unknown = grouped.keys.filter { !ListCommand.categoryOrder.contains($0) }.sorted()
        let maxID = bundled.map { $0.id.count }.max() ?? 0

        var first = true
        for category in known + unknown {
            guard let entries = grouped[category] else { continue }
            if !first { print() }
            first = false
            print(Ansi.bold(Ansi.underline(category)))
            for schema in entries.sorted(by: { $0.id < $1.id }) {
                let installed = AppDetector.isInstalled(schema)
                let marker = installed ? Ansi.green("●") : Ansi.dim("○")
                let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
                let id = installed ? schema.id : Ansi.dim(schema.id)
                let name = installed ? schema.name : Ansi.dim(schema.name)
                print("  \(marker) \(id)\(pad)  \(name)")
            }
        }
        print()
        print(Ansi.dim("\(bundled.count) bundled schemas — run `dotty add <id>` to use one"))
    }

    private func printSchema(_ schema: AppSchema) throws {
        struct Payload: Codable {
            let name: String
            let category: String?
            let strategy: SyncStrategy?
            let destination: String?
            let paths: [PathSpec]
        }
        let payload = Payload(name: schema.name, category: schema.category, strategy: schema.strategy, destination: schema.destination, paths: schema.paths)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(data: data, encoding: .utf8) ?? "")
    }
}
