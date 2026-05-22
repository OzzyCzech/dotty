import ArgumentParser
import Foundation

struct ReinitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reinit",
        abstract: "Reconfigure ~/.dotty/ — picker preselects current set; deselecting removes schemas.",
        discussion: """
        Uses your current `destination` as the prompt default. The picker shows
        every detected app with the currently-configured ones preselected.
        Deselecting an app **deletes** its ~/.dotty/<id>.json file; selecting a
        new app writes a fresh template. Existing schema files for apps that
        stay selected are preserved (your edits are kept) unless --refresh is
        set, which overwrites them from the bundled templates.
        """
    )

    @Option(name: .long, help: "Destination directory (skips the destination prompt).")
    var destination: String?

    @Flag(name: .long, help: "Overwrite existing schema contents with the bundled templates.")
    var refresh: Bool = false

    @Flag(name: [.short, .long], help: "Accept all defaults — keep current selection and destination.")
    var yes: Bool = false

    func run() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)

        let existingConfig = DottyConfig.load()
        let destPath: String = {
            if let destination { return destination }
            if yes { return existingConfig.destination }
            return Confirmation.askText("Destination", default: existingConfig.destination)
        }()

        let builtins = SchemaRegistry.bundledBuiltins()
        let existing = SchemaRegistry().all()                       // user's current standalones (full data, incl. custom)
        let existingIDs = Set(existing.map { $0.id })
        let installedNotConfigured = builtins
            .filter { AppDetector.isInstalled($0) }
            .filter { !existingIDs.contains($0.id) }

        // Picker shows: every existing schema (preselected) + every detected-installed builtin not yet configured.
        let displayed = existing + installedNotConfigured

        if displayed.isEmpty {
            try SchemaSetup.writeRootConfig(destination: destPath)
            print("Wrote \(Paths.short(Paths.configFile.path)). Nothing else to do.")
            return
        }

        let chosenIDs: [String]
        if yes || !InteractivePicker.isAvailable {
            chosenIDs = Array(existingIDs)
        } else {
            let rows = SchemaSetup.buildPickerRows(displayed)
            guard let picked = InteractivePicker.multiSelect(
                title: "Reconfigure ~/.dotty/ — toggle apps; deselecting deletes the schema",
                rows: rows,
                initiallySelected: existingIDs
            ) else {
                print("Aborted.")
                return
            }
            chosenIDs = picked
        }

        let chosen = Set(chosenIDs)
        let toAdd = chosen.subtracting(existingIDs)
        let toRemove = existingIDs.subtracting(chosen)
        let toRefresh: Set<String> = refresh ? chosen.intersection(existingIDs) : []

        // Show diff and confirm if there's anything to remove (destructive).
        if !toAdd.isEmpty || !toRemove.isEmpty || !toRefresh.isEmpty {
            print()
            print(Ansi.bold("Planned changes"))
            if !toAdd.isEmpty {
                print("  \(Ansi.green("+")) add:     \(toAdd.sorted().joined(separator: ", "))")
            }
            if !toRemove.isEmpty {
                print("  \(Ansi.yellow("-")) remove:  \(toRemove.sorted().joined(separator: ", "))")
            }
            if !toRefresh.isEmpty {
                print("  \(Ansi.cyan("~")) refresh: \(toRefresh.sorted().joined(separator: ", "))")
            }
            if destPath != existingConfig.destination {
                print("  \(Ansi.cyan("~")) destination: \(existingConfig.destination) → \(destPath)")
            }
            print()
            if !yes && !toRemove.isEmpty {
                if !Confirmation.ask("Apply changes?", defaultYes: true) {
                    print("Aborted.")
                    return
                }
            }
        } else if destPath == existingConfig.destination {
            print("No changes.")
            return
        }

        var added = 0, removed = 0, refreshed = 0
        for id in toAdd {
            guard let schema = builtins.first(where: { $0.id == id }) else { continue }
            try SchemaSetup.writeSchema(schema, to: Paths.dottyDir.appendingPathComponent("\(id).json"))
            added += 1
        }
        for id in toRemove {
            let url = Paths.dottyDir.appendingPathComponent("\(id).json")
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
                removed += 1
            }
        }
        for id in toRefresh {
            guard let schema = builtins.first(where: { $0.id == id }) else { continue }
            try SchemaSetup.writeSchema(schema, to: Paths.dottyDir.appendingPathComponent("\(id).json"))
            refreshed += 1
        }
        try SchemaSetup.writeRootConfig(destination: destPath)

        print()
        var parts: [String] = []
        if added > 0 { parts.append("Added: \(added)") }
        if removed > 0 { parts.append("Removed: \(removed)") }
        if refreshed > 0 { parts.append("Refreshed: \(refreshed)") }
        if parts.isEmpty {
            parts.append("Destination updated")
        }
        print(Ansi.dim(parts.joined(separator: "  ")))
    }
}
