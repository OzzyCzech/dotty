import ArgumentParser
import Foundation

struct LinkCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link",
        abstract: "Replace source files with symlinks to backup directory."
    )

    @Argument(help: "App identifier (omit to link all installed apps).")
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

        let manager = SymlinkManager(dryRun: dryRun, verbose: verbose)
        for (i, schema) in targets.enumerated() {
            if i > 0 { print() }
            manager.link(schema: schema, backupDir: registry.backupDir(for: schema))
        }
        manager.summary()
        if manager.failed > 0 { throw ExitCode(2) }
    }
}
