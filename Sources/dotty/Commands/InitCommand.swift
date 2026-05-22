import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Interactively create ~/.dotty/config.json — detects installed apps and writes an enabled whitelist."
    )

    @Option(name: .long, help: "Backup destination directory (skips destination prompt).")
    var destination: String?

    @Flag(name: .long, help: "Overwrite existing config without prompting.")
    var force: Bool = false

    @Flag(name: [.short, .long], help: "Accept all defaults — enable every detected app.")
    var yes: Bool = false

    func run() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)
        let configURL = Paths.configFile

        if fm.fileExists(atPath: configURL.path) && !force {
            if !Confirmation.ask("\(Paths.short(configURL.path)) exists. Overwrite?") {
                print("Aborted.")
                return
            }
        }

        let destPath: String = {
            if let destination { return destination }
            if yes { return DottyConfig.defaultDestination }
            return Confirmation.askText("Backup destination", default: DottyConfig.defaultDestination)
        }()

        let registry = SchemaRegistry(config: DottyConfig.empty())
        let installed = registry.all().filter { AppDetector.isInstalled($0) }

        if installed.isEmpty {
            print("No installed apps detected from built-in schemas.")
            try writeConfig(url: configURL, destination: destPath, enabled: nil)
            print("Wrote \(Paths.short(configURL.path)) (no apps enabled — edit it to add some).")
            return
        }

        var enabledIDs: [String]
        if yes || !InteractivePicker.isAvailable {
            print()
            print(Ansi.bold("Detected \(installed.count) installed apps"))
            printGrouped(installed)
            print()
            enabledIDs = installed.map { $0.id }
            if !yes {
                if !Confirmation.ask("Enable all of them?", defaultYes: true) {
                    let excluded = Confirmation.askText("Enter IDs to EXCLUDE (space-separated)", default: "")
                    let drop = Set(excluded.split(separator: " ").map { $0.lowercased() })
                    enabledIDs = enabledIDs.filter { !drop.contains($0) }
                }
            }
        } else {
            let rows = buildPickerRows(installed)
            let allIDs = Set(installed.map { $0.id })
            guard let picked = InteractivePicker.multiSelect(
                title: "Detected \(installed.count) installed apps — pick which to enable",
                rows: rows,
                initiallySelected: allIDs
            ) else {
                print("Aborted.")
                return
            }
            enabledIDs = picked
        }

        try writeConfig(url: configURL, destination: destPath, enabled: enabledIDs)
        print()
        print("Wrote \(Paths.short(configURL.path)) with \(enabledIDs.count) enabled app\(enabledIDs.count == 1 ? "" : "s").")
        print(Ansi.dim("Nothing was copied or linked. Run `dotty save` to push your current configs into the backup directory."))
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

    private func writeConfig(url: URL, destination: String, enabled: [String]?) throws {
        var payload: [String: Any] = ["destination": destination]
        if let enabled {
            payload["enabled"] = enabled.sorted()
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }
}
