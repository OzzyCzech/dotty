import ArgumentParser
import Foundation

struct LinkCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link",
        abstract: "Wire up home with symlinks to the destination directory.",
        discussion: """
        Idempotent. For each path declared in your schemas dotty figures out
        what to do from current on-disk state:

          • home file exists, destination empty  → move home → destination + symlink
          • destination exists, home empty       → create symlink pointing at destination
          • home already symlinks to destination → no-op
          • both home and destination exist      → conflict, asks you to resolve manually
        """
    )

    @Argument(help: "App identifier (omit to link all configured apps).")
    var app: String?

    @Flag(name: .long, help: "Preview without writing.")
    var dryRun: Bool = false

    @Flag(name: [.short, .long], help: "Verbose output.")
    var verbose: Bool = false

    func run() throws {
        let registry = SchemaRegistry()
        let targets: [AppSchema]
        if let app {
            guard let schema = registry.find(app) else {
                FileHandle.standardError.write(Data("Unknown app: \(app)\n".utf8))
                throw ExitCode(1)
            }
            targets = [schema]
        } else {
            targets = registry.all()
        }

        let engine = SyncEngine(dryRun: dryRun, verbose: verbose)
        for (i, schema) in targets.enumerated() {
            if i > 0 { print() }
            engine.run(operation: .link, schema: schema, destinationDir: registry.destinationDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
