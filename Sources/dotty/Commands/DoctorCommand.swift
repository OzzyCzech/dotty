import ArgumentParser
import Foundation

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Report config health, broken symlinks, and stray files."
    )

    @Flag(name: .long, help: "Show every app, even those without issues.")
    var all: Bool = false

    func run() throws {
        let fm = FileManager.default
        let registry = SchemaRegistry()

        print(Ansi.bold("Destination"))
        let destExpanded = Paths.expand(registry.config.destination)
        let destExists = fm.fileExists(atPath: destExpanded)
        let destMark = destExists ? Ansi.green("✓") : Ansi.yellow("○")
        let destNote = destExists ? Ansi.dim("exists") : Ansi.dim("not created yet")
        print("  \(destMark) \(registry.config.destination)  \(destNote)")
        print()

        var totalIssues = 0
        var totalApps = 0
        var appsWithIssues = 0
        var perCategory: [String: [(schema: AppSchema, issues: [String], hasIssue: Bool)]] = [:]

        for schema in registry.all() {
            totalApps += 1
            let issues = analyze(schema: schema, registry: registry, fm: fm)
            let hasIssue = !issues.allSatisfy { !$0.isError }
            if hasIssue { appsWithIssues += 1 }
            totalIssues += issues.filter { $0.isError }.count

            let cat = schema.category ?? "Other"
            perCategory[cat, default: []].append((schema, issues.map { $0.text }, hasIssue))
        }

        let ordered = ListCommand.categoryOrder.filter { perCategory[$0] != nil }
            + perCategory.keys.filter { !ListCommand.categoryOrder.contains($0) }.sorted()

        var firstSection = true
        for category in ordered {
            let entries = (perCategory[category] ?? []).filter { all || $0.hasIssue }
            if entries.isEmpty { continue }
            if !firstSection { print() }
            firstSection = false
            print(Ansi.bold(Ansi.underline(category)))
            for entry in entries.sorted(by: { $0.schema.id < $1.schema.id }) {
                let marker = entry.hasIssue ? Ansi.yellow("⚠") : Ansi.green("✓")
                let label = entry.hasIssue ? entry.schema.id : Ansi.dim(entry.schema.id)
                print("  \(marker) \(label)  \(Ansi.dim(entry.schema.name))")
                if all || entry.hasIssue {
                    for issue in entry.issues {
                        print("      \(issue)")
                    }
                }
            }
        }

        if firstSection {
            print(Ansi.green("✓ Everything looks healthy."))
        }

        print()
        let summary = "\(totalApps) apps · \(appsWithIssues) with issues · \(totalIssues) problems"
        print(Ansi.dim(summary))
    }

    private struct Finding {
        let text: String
        let isError: Bool
    }

    private func analyze(schema: AppSchema, registry: SchemaRegistry, fm: FileManager) -> [Finding] {
        var findings: [Finding] = []
        let installed = AppDetector.isInstalled(schema)
        if !installed {
            findings.append(Finding(text: Ansi.dim("not installed"), isError: false))
        }
        let backupDir = registry.backupDir(for: schema)
        for path in schema.paths {
            let expanded = Paths.expand(path)
            let exists = fm.fileExists(atPath: expanded)
            let attrs = try? fm.attributesOfItem(atPath: expanded)
            let isLink = (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
            let backupPath = backupDir.appendingPathComponent(Paths.relativeToBackupRoot(absolute: expanded))
            let backupExists = fm.fileExists(atPath: backupPath.path)

            if isLink {
                if let dest = try? fm.destinationOfSymbolicLink(atPath: expanded) {
                    let resolved = URL(fileURLWithPath: dest, relativeTo: URL(fileURLWithPath: expanded).deletingLastPathComponent()).standardizedFileURL
                    if !fm.fileExists(atPath: resolved.path) {
                        findings.append(Finding(text: "\(Ansi.yellow("✗")) broken symlink: \(Paths.short(expanded)) → \(dest)", isError: true))
                    } else if resolved.path == backupPath.standardizedFileURL.path {
                        findings.append(Finding(text: "\(Ansi.cyan("↪")) linked: \(Paths.short(expanded))", isError: false))
                    } else {
                        findings.append(Finding(text: "\(Ansi.dim("·")) symlink to non-backup: \(Paths.short(expanded)) → \(Paths.short(resolved.path))", isError: false))
                    }
                }
            } else if !exists && installed {
                findings.append(Finding(text: "\(Ansi.yellow("⚠")) missing: \(Paths.short(expanded))", isError: true))
            } else if exists && backupExists {
                // both present — fine in copy mode, conflict in link mode
                continue
            } else if exists {
                continue
            }
        }
        return findings
    }
}
