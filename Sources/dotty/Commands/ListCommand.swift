import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show configured apps in ~/.dotty/. Use `dotty schemas` to browse bundled schemas."
    )

    @Flag(name: .long, help: "Show only installed apps.")
    var installed: Bool = false

    @Flag(name: .long, help: "Show only apps that are not installed.")
    var missing: Bool = false

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
        let all = SchemaRegistry().all()

        let filtered = all.filter { schema in
            let isInstalled = AppDetector.isInstalled(schema)
            if installed && !isInstalled { return false }
            if missing && isInstalled { return false }
            return true
        }

        if filtered.isEmpty {
            print("No configured apps. Run `dotty init` to bootstrap, or `dotty schemas` to browse bundled schemas.")
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
                print("  \(marker) \(id)\(pad)  \(name)")
            }
        }

        print()
        let total = filtered.count
        let notInstalled = total - installedCount
        print(Ansi.dim("\(total) configured apps · \(installedCount) installed · \(notInstalled) not installed"))
    }
}
