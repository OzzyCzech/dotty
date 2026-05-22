import ArgumentParser
import Foundation

struct RestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Copy from backup directory to original location."
    )

    @Argument(help: "App identifier (omit to restore all).")
    var app: String?

    @Flag(name: .long, help: "Skip confirmation prompts.")
    var force: Bool = false

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

        let copier = FileCopier(dryRun: dryRun, verbose: verbose)
        var any = false
        for schema in targets {
            if !force {
                if !Confirmation.ask("Restore \(schema.name)?") {
                    continue
                }
            }
            if any { print() }
            any = true
            copier.restore(schema: schema, backupDir: registry.backupDir(for: schema))
        }
        copier.summary()
        if copier.failed > 0 { throw ExitCode(2) }
    }
}
