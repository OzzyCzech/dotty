import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show all known apps."
    )

    func run() throws {
        let registry = SchemaRegistry()
        let schemas = registry.all()
        if schemas.isEmpty {
            print("No schemas available.")
            return
        }
        let maxID = schemas.map { $0.id.count }.max() ?? 0
        for schema in schemas {
            let installed = AppDetector.isInstalled(schema) ? "●" : "○"
            let source = registry.source(of: schema.id)?.rawValue ?? "?"
            let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
            print("\(installed) \(schema.id)\(pad)  \(schema.name)  [\(source)]")
        }
        print()
        print("● installed   ○ not installed")
    }
}
