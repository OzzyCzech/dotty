import ArgumentParser
import Foundation

struct SnapshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Pure copy of home dotfiles into the destination directory. Ignores strategy.",
        discussion: """
        Use this for a safety copy without committing to symlinks. Home files are
        untouched. Every path is copied (even link-strategy paths). Run this any
        time you want a fresh snapshot.
        """
    )

    @Argument(help: "App identifier (omit to snapshot all installed apps).")
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
            engine.run(operation: .snapshot, schema: schema, backupDir: registry.backupDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
