import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show configured apps in ~/.dotty/ (or use --available to browse bundled schemas)."
    )

    @Flag(name: .long, help: "Show only installed apps.")
    var installed: Bool = false

    @Flag(name: .long, help: "Show only apps that are not installed.")
    var missing: Bool = false

    @Flag(name: .long, help: "Show bundled built-in schemas (templates available to `dotty init`), not the configured ones.")
    var available: Bool = false

    @Flag(name: [.short, .long], help: "Compact one-line output (just identifiers).")
    var compact: Bool = false

    static let categoryOrder: [String] = [
        "Editors",
        "AI Tools",
        "Terminals",
        "Shell",
        "Git",
        "Languages",
        "DevOps",
        "CLI Utilities",
        "macOS Apps",
        "Other",
    ]

    func run() throws {
        let all: [AppSchema] = available
            ? SchemaRegistry.bundledBuiltins()
            : SchemaRegistry().all()

        let filtered = all.filter { schema in
            let isInstalled = AppDetector.isInstalled(schema)
            if installed && !isInstalled { return false }
            if missing && isInstalled { return false }
            return true
        }

        if filtered.isEmpty {
            if available {
                print("No bundled schemas match the given filters.")
            } else {
                print("No configured apps. Run `dotty init` to add some, or `dotty list --available` to browse bundled schemas.")
            }
            return
        }

        if compact {
            print(filtered.map { $0.id }.joined(separator: " "))
            return
        }

        let grouped = Dictionary(grouping: filtered) { $0.category ?? "Other" }
        let knownOrdered = Self.categoryOrder.filter { grouped[$0] != nil }
        let unknown = grouped.keys.filter { !Self.categoryOrder.contains($0) }.sorted()
        let categories = knownOrdered + unknown

        let maxID = filtered.map { $0.id.count }.max() ?? 0

        var first = true
        var installedCount = 0
        for category in categories {
            guard let entries = grouped[category] else { continue }
            if !first { print() }
            first = false
            print(Ansi.bold(Ansi.underline(category)))
            for schema in entries.sorted(by: { $0.id < $1.id }) {
                let isInstalled = AppDetector.isInstalled(schema)
                if isInstalled { installedCount += 1 }
                let marker = isInstalled ? Ansi.green("●") : Ansi.dim("○")
                let pad = String(repeating: " ", count: max(0, maxID - schema.id.count))
                let id = isInstalled ? schema.id : Ansi.dim(schema.id)
                let name = isInstalled ? schema.name : Ansi.dim(schema.name)
                let modeTag: String = {
                    let hasLink = schema.hasLinkPaths()
                    let hasCopy = schema.hasCopyPaths()
                    switch (hasLink, hasCopy) {
                    case (true, true):   return "  " + Ansi.dim("mixed")
                    case (true, false):  return "  " + Ansi.dim("link")
                    case (false, true):  return ""
                    case (false, false): return ""
                    }
                }()
                print("  \(marker) \(id)\(pad)  \(name)\(modeTag)")
            }
        }

        print()
        let total = filtered.count
        let notInstalled = total - installedCount
        let header = available ? "bundled" : "configured"
        print(Ansi.dim("\(total) \(header) apps · \(installedCount) installed · \(notInstalled) not installed"))
    }
}
