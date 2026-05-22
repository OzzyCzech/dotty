import ArgumentParser
import Foundation

struct SaveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "save",
        abstract: "home → backup. Copies files, ensures symlinks for link-strategy paths.",
        discussion: """
        For copy-mode paths, the source file is copied to the backup directory.
        For link-mode paths, the source is moved into the backup directory and
        replaced with a symlink (idempotent — already-linked paths are skipped).
        """
    )

    @Argument(help: "App identifier (omit to save all installed apps).")
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
            targets = registry.all().filter { AppDetector.isInstalled($0) }
        }

        let engine = SyncEngine(dryRun: dryRun, verbose: verbose)
        for (i, schema) in targets.enumerated() {
            if i > 0 { print() }
            engine.run(direction: .save, schema: schema, backupDir: registry.backupDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
