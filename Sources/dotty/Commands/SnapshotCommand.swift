import ArgumentParser
import Foundation

struct SnapshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Pure copy of home dotfiles into the destination directory (no symlinks).",
        discussion: """
        Use this when you want a plain copy in the destination directory instead
        of the usual symlink wiring (`dotty link`). Home files are untouched.
        Useful for one-off backups or paths that don't symlink well (binary
        plists managed by cfprefsd, machine-specific configs, etc.).
        """
    )

    @Argument(help: "App identifier (omit to snapshot all configured apps).")
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
            engine.run(operation: .snapshot, schema: schema, destinationDir: registry.destinationDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
