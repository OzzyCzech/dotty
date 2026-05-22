import ArgumentParser
import Foundation

struct AdoptCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adopt",
        abstract: "Take home dotfiles under management — move into destination + symlink back.",
        discussion: """
        One-time bootstrap. For link-strategy paths the source file is moved into
        the destination directory and replaced with a symlink (so you can put the
        destination in git and edit through the symlink). Copy-strategy paths are
        copied without modifying home. Idempotent — already-adopted paths are
        skipped.
        """
    )

    @Argument(help: "App identifier (omit to adopt all installed apps).")
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
            engine.run(operation: .adopt, schema: schema, backupDir: registry.backupDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
