import ArgumentParser
import Foundation

struct RestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Apply backup to home — copies files and ensures symlinks.",
        discussion: """
        For copy-mode paths, the backup is copied back to the source location
        (overwriting existing files — confirm per-app unless --force).
        For link-mode paths, a symlink is created pointing at the backup.
        """
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

        let engine = SyncEngine(dryRun: dryRun, verbose: verbose)
        var any = false
        for schema in targets {
            if !force, schema.hasCopyPaths() {
                if !Confirmation.ask("Restore \(schema.name)?") { continue }
            }
            if any { print() }
            any = true
            engine.run(direction: .restore, schema: schema, backupDir: registry.backupDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
