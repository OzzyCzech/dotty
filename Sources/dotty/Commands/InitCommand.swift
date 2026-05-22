import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "First-time setup of ~/.dotty/. Use `dotty reinit` to reconfigure an existing setup."
    )

    @Option(name: .long, help: "Destination directory (skips the destination prompt).")
    var destination: String?

    @Flag(name: [.short, .long], help: "Accept all defaults — write a schema for every detected app.")
    var yes: Bool = false

    @Flag(name: .long, help: "Overwrite an existing config without redirecting to `reinit`.")
    var force: Bool = false

    func run() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)

        if fm.fileExists(atPath: Paths.configFile.path) && !force {
            FileHandle.standardError.write(Data("\(Paths.short(Paths.configFile.path)) already exists. Run `dotty reinit` to reconfigure, or `dotty init --force` to start over.\n".utf8))
            throw ExitCode(1)
        }

        let destPath: String = {
            if let destination { return destination }
            if yes { return DottyConfig.defaultDestination }
            return Confirmation.askText("Destination", default: DottyConfig.defaultDestination)
        }()

        let builtins = SchemaRegistry.bundledBuiltins()
        let installed = builtins.filter { AppDetector.isInstalled($0) }

        if installed.isEmpty {
            try SchemaSetup.writeRootConfig(destination: destPath)
            print("Wrote \(Paths.short(Paths.configFile.path)) (no installed apps detected).")
            return
        }

        let chosenIDs: [String]
        if yes || !InteractivePicker.isAvailable {
            print()
            print(Ansi.bold("Detected \(installed.count) installed apps"))
            SchemaSetup.printGrouped(installed)
            print()
            var ids = installed.map { $0.id }
            if !yes {
                if !Confirmation.ask("Enable all of them?", defaultYes: true) {
                    let excluded = Confirmation.askText("Enter IDs to EXCLUDE (space-separated)", default: "")
                    let drop = Set(excluded.split(separator: " ").map { $0.lowercased() })
                    ids = ids.filter { !drop.contains($0) }
                }
            }
            chosenIDs = ids
        } else {
            let rows = SchemaSetup.buildPickerRows(installed)
            guard let picked = InteractivePicker.multiSelect(
                title: "Detected \(installed.count) installed apps — pick which to manage",
                rows: rows,
                initiallySelected: Set(installed.map { $0.id })
            ) else {
                print("Aborted.")
                return
            }
            chosenIDs = picked
        }

        let chosen = Set(chosenIDs)
        var written = 0
        for schema in installed where chosen.contains(schema.id) {
            let url = Paths.dottyDir.appendingPathComponent("\(schema.id).json")
            try SchemaSetup.writeSchema(schema, to: url)
            written += 1
        }
        try SchemaSetup.writeRootConfig(destination: destPath)

        print()
        print("Wrote \(Paths.short(Paths.configFile.path)) and \(written) schema file\(written == 1 ? "" : "s") in \(Paths.short(Paths.dottyDir.path))/.")
        print(Ansi.dim("Nothing was copied or linked. Edit the schemas as needed, then run `dotty adopt` (one-time bootstrap), `dotty snapshot` (safety copy), or `dotty deploy` (apply destination to home)."))
    }
}
