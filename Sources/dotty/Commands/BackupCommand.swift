import ArgumentParser
import Foundation

struct BackupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backup",
        abstract: "Copy app config to backup directory."
    )

    @Argument(help: "App identifier (omit to back up all installed apps).")
    var app: String?

    @Flag(name: .long, help: "Preview without writing.")
    var dryRun: Bool = false

    @Flag(name: [.short, .long], help: "Verbose output.")
    var verbose: Bool = false

    func run() throws {
        let registry = SchemaRegistry()
        let targets = try resolveTargets(registry: registry)
        let copier = FileCopier(dryRun: dryRun, verbose: verbose)

        for (i, schema) in targets.enumerated() {
            if i > 0 { print() }
            copier.backup(schema: schema, backupDir: registry.backupDir(for: schema))
        }
        copier.summary()
        if copier.failed > 0 { throw ExitCode(2) }
    }

    private func resolveTargets(registry: SchemaRegistry) throws -> [AppSchema] {
        if let app {
            guard let schema = registry.find(app) else {
                FileHandle.standardError.write(Data("Unknown app: \(app)\n".utf8))
                throw ExitCode(1)
            }
            return [schema]
        }
        return registry.all().filter { AppDetector.isInstalled($0) }
    }
}
