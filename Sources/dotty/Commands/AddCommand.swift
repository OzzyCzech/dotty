import ArgumentParser
import Foundation

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Copy a bundled template into ~/.dotty/<id>.json."
    )

    @Argument(help: "App identifier (see `dotty templates`).")
    var app: String

    @Flag(name: .long, help: "Overwrite an existing ~/.dotty/<id>.json file.")
    var refresh: Bool = false

    func run() throws {
        let id = app.lowercased()
        guard let schema = SchemaRegistry.bundledBuiltins().first(where: { $0.id == id }) else {
            FileHandle.standardError.write(Data("No bundled template for '\(id)'. Run `dotty templates` to list available templates.\n".utf8))
            throw ExitCode(1)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)
        let url = Paths.dottyDir.appendingPathComponent("\(id).json")

        if fm.fileExists(atPath: url.path) && !refresh {
            FileHandle.standardError.write(Data("\(Paths.short(url.path)) already exists. Use --refresh to overwrite.\n".utf8))
            throw ExitCode(1)
        }

        try SchemaWriter.write(schema, to: url)
        print("Wrote \(Paths.short(url.path))")
    }
}

enum SchemaWriter {
    static func write(_ schema: AppSchema, to url: URL) throws {
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
        try data.write(to: url)
    }
}
