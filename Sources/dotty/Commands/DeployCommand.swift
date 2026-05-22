import ArgumentParser
import Foundation

struct DeployCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deploy",
        abstract: "Deploy destination state to home — creates symlinks (link strategy) or copies (copy strategy).",
        discussion: """
        Use on a fresh Mac to wire up dotfiles from the destination directory, or
        any time you want to ensure home matches the destination. For link-strategy
        paths a symlink is created; for copy-strategy paths the file is copied
        (with per-app confirmation unless --force is set).
        """
    )

    @Argument(help: "App identifier (omit to deploy all).")
    var app: String?

    @Flag(name: .long, help: "Skip the per-app confirmation prompt.")
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
                if !Confirmation.ask("Deploy \(schema.name)?") { continue }
            }
            if any { print() }
            any = true
            engine.run(operation: .deploy, schema: schema, backupDir: registry.backupDir(for: schema))
        }
        engine.summary()
        if engine.failed > 0 { throw ExitCode(2) }
    }
}
