import ArgumentParser
import Foundation

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Report config health."
    )

    func run() throws {
        let fm = FileManager.default
        let registry = SchemaRegistry()

        print("Destination: \(registry.config.destination)")
        let destExists = fm.fileExists(atPath: Paths.expand(registry.config.destination))
        print("  \(destExists ? "✓" : "○") \(destExists ? "exists" : "not created yet")")
        print()

        var issues = 0

        for schema in registry.all() {
            let installed = AppDetector.isInstalled(schema)
            let src = registry.source(of: schema.id)?.rawValue ?? "?"
            print("\(schema.id)  [\(src)]\(installed ? "" : "  (not installed)")")
            let backupDir = registry.backupDir(for: schema)
            for path in schema.paths {
                let expanded = Paths.expand(path)
                let exists = fm.fileExists(atPath: expanded)
                let attrs = try? fm.attributesOfItem(atPath: expanded)
                let isLink = (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
                let backupPath = backupDir.appendingPathComponent(Paths.relativeToBackupRoot(absolute: expanded))
                let backupExists = fm.fileExists(atPath: backupPath.path)

                var marks: [String] = []
                if isLink {
                    if let dest = try? fm.destinationOfSymbolicLink(atPath: expanded) {
                        let resolved = URL(fileURLWithPath: dest, relativeTo: URL(fileURLWithPath: expanded).deletingLastPathComponent()).standardizedFileURL
                        if !fm.fileExists(atPath: resolved.path) {
                            marks.append("broken symlink → \(dest)")
                            issues += 1
                        } else {
                            marks.append("symlink → \(Paths.short(resolved.path))")
                        }
                    }
                } else if !exists {
                    marks.append("source missing")
                }
                if backupExists {
                    marks.append("backup present")
                }
                print("  \(Paths.short(expanded))  \(marks.joined(separator: ", "))")
            }
        }

        print()
        print(issues == 0 ? "No issues detected." : "Issues: \(issues)")
    }
}
