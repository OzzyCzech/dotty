import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Interactively populate ~/.dotty/ with schemas for installed apps."
    )

    @Option(name: .long, help: "Backup destination directory (skips the destination prompt).")
    var destination: String?

    @Flag(name: .long, help: "Overwrite existing ~/.dotty/<id>.json files.")
    var refresh: Bool = false

    @Flag(name: [.short, .long], help: "Accept all defaults — write a schema for every detected app.")
    var yes: Bool = false

    func run() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)

        let existingConfig = DottyConfig.load()
        let destPath: String = {
            if let destination { return destination }
            if yes { return existingConfig.destination }
            return Confirmation.askText("Backup destination", default: existingConfig.destination)
        }()

        let builtins = SchemaRegistry.bundledBuiltins()
        let installed = builtins.filter { AppDetector.isInstalled($0) }

        if installed.isEmpty {
            try writeRootConfig(destination: destPath)
            print("Wrote \(Paths.short(Paths.configFile.path)) (no installed apps detected).")
            return
        }

        let existingIDs = Set(loadExistingSchemaIDs())

        let chosenIDs: [String]
        if yes || !InteractivePicker.isAvailable {
            print()
            print(Ansi.bold("Detected \(installed.count) installed apps"))
            printGrouped(installed)
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
            let rows = buildPickerRows(installed)
            let preselected = existingIDs.isEmpty ? Set(installed.map { $0.id }) : existingIDs
            guard let picked = InteractivePicker.multiSelect(
                title: "Detected \(installed.count) installed apps — pick which to manage",
                rows: rows,
                initiallySelected: preselected
            ) else {
                print("Aborted.")
                return
            }
            chosenIDs = picked
        }

        let chosen = Set(chosenIDs)
        var written = 0
        var skipped = 0
        for schema in installed where chosen.contains(schema.id) {
            let url = Paths.dottyDir.appendingPathComponent("\(schema.id).json")
            if fm.fileExists(atPath: url.path) && !refresh {
                skipped += 1
                continue
            }
            try writeSchema(schema, to: url)
            written += 1
        }
        try writeRootConfig(destination: destPath)

        print()
        print("Wrote \(Paths.short(Paths.configFile.path)) and \(written) schema file\(written == 1 ? "" : "s") in \(Paths.short(Paths.dottyDir.path))/.")
        if skipped > 0 {
            print(Ansi.dim("Skipped \(skipped) existing schema file\(skipped == 1 ? "" : "s") (rerun with --refresh to overwrite)."))
        }
        print(Ansi.dim("Nothing was copied or linked. Edit the schemas as needed, then run `dotty save`."))
    }

    private func loadExistingSchemaIDs() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: Paths.dottyDir, includingPropertiesForKeys: nil) else { return [] }
        return entries
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
            .filter { $0 != "config" }
    }

    private func writeSchema(_ schema: AppSchema, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Encode without the runtime-only `id` field.
        struct Payload: Codable {
            let name: String
            let category: String?
            let strategy: SyncStrategy?
            let destination: String?
            let paths: [PathSpec]
        }
        let payload = Payload(name: schema.name, category: schema.category, strategy: schema.strategy, destination: schema.destination, paths: schema.paths)
        let data = try encoder.encode(payload)
        try data.write(to: url)
    }

    private func writeRootConfig(destination: String) throws {
        let payload: [String: Any] = ["destination": destination]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: Paths.configFile)
    }

    private func buildPickerRows(_ schemas: [AppSchema]) -> [PickerRow] {
        let grouped = Dictionary(grouping: schemas) { $0.category ?? "Other" }
        let ordered = ListCommand.categoryOrder.filter { grouped[$0] != nil }
            + grouped.keys.filter { !ListCommand.categoryOrder.contains($0) }.sorted()
        let maxID = schemas.map { $0.id.count }.max() ?? 0
        var rows: [PickerRow] = []
        for category in ordered {
            guard let entries = grouped[category] else { continue }
            rows.append(.header(category))
            for schema in entries.sorted(by: { $0.id < $1.id }) {
                let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
                rows.append(.item(id: schema.id, label: schema.id + pad, secondary: schema.name))
            }
        }
        return rows
    }

    private func printGrouped(_ schemas: [AppSchema]) {
        let grouped = Dictionary(grouping: schemas) { $0.category ?? "Other" }
        let ordered = ListCommand.categoryOrder.filter { grouped[$0] != nil }
            + grouped.keys.filter { !ListCommand.categoryOrder.contains($0) }.sorted()
        let maxID = schemas.map { $0.id.count }.max() ?? 0
        for category in ordered {
            guard let entries = grouped[category] else { continue }
            print()
            print(Ansi.bold(Ansi.underline(category)))
            for schema in entries.sorted(by: { $0.id < $1.id }) {
                let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
                print("  \(Ansi.green("●")) \(schema.id)\(pad)  \(Ansi.dim(schema.name))")
            }
        }
    }
}
