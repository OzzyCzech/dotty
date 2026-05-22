import Foundation

final class SymlinkManager {
    private let fm = FileManager.default
    private let dryRun: Bool
    private let verbose: Bool

    var linked = 0
    var skipped = 0
    var failed = 0

    init(dryRun: Bool = false, verbose: Bool = false) {
        self.dryRun = dryRun
        self.verbose = verbose
    }

    func link(schema: AppSchema, backupDir: URL) {
        print(schema.name)
        for spec in schema.paths {
            let src = URL(fileURLWithPath: Paths.expand(spec.source))
            let backup = backupDir.appendingPathComponent(spec.resolvedTarget())
            report(path: src.path, outcome: linkOne(source: src, backup: backup))
        }
    }

    func unlink(schema: AppSchema, backupDir: URL) {
        print(schema.name)
        for spec in schema.paths {
            let src = URL(fileURLWithPath: Paths.expand(spec.source))
            let backup = backupDir.appendingPathComponent(spec.resolvedTarget())
            report(path: src.path, outcome: unlinkOne(source: src, backup: backup))
        }
    }

    private func linkOne(source: URL, backup: URL) -> CopyOutcome {
        let srcExists = exists(source)
        let backupExists = fm.fileExists(atPath: backup.path)
        let srcIsSymlink = isSymlink(source)

        // Idempotent: already a symlink to backup
        if srcIsSymlink, let dest = try? fm.destinationOfSymbolicLink(atPath: source.path) {
            let resolved = URL(fileURLWithPath: dest, relativeTo: source.deletingLastPathComponent()).standardizedFileURL
            if resolved.path == backup.standardizedFileURL.path {
                return .skipped(reason: "already linked")
            }
        }

        switch (srcExists && !srcIsSymlink, backupExists) {
        case (false, true):
            return createSymlink(at: source, target: backup)
        case (true, false):
            if dryRun {
                return .linked
            }
            do {
                try fm.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: source, to: backup)
                return createSymlink(at: source, target: backup)
            } catch {
                return .failed(error)
            }
        case (true, true):
            return .skipped(reason: "conflict: both source and backup exist; resolve manually")
        case (false, false):
            if srcIsSymlink {
                return .skipped(reason: "broken symlink")
            }
            return .skipped(reason: "not found")
        }
    }

    private func unlinkOne(source: URL, backup: URL) -> CopyOutcome {
        guard isSymlink(source) else {
            return .skipped(reason: "not a symlink")
        }
        guard fm.fileExists(atPath: backup.path) else {
            return .skipped(reason: "backup missing")
        }
        if dryRun {
            return .copied
        }
        do {
            try fm.removeItem(at: source)
            try fm.copyItem(at: backup, to: source)
            return .copied
        } catch {
            return .failed(error)
        }
    }

    private func createSymlink(at source: URL, target: URL) -> CopyOutcome {
        if dryRun {
            return .linked
        }
        do {
            try fm.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Remove any stale entry (e.g. broken symlink)
            if isSymlink(source) || fm.fileExists(atPath: source.path) {
                try fm.removeItem(at: source)
            }
            try fm.createSymbolicLink(at: source, withDestinationURL: target)
            return .linked
        } catch {
            return .failed(error)
        }
    }

    private func isSymlink(_ url: URL) -> Bool {
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        return (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    private func exists(_ url: URL) -> Bool {
        // fileExists follows symlinks, so combine with lstat-style check
        if isSymlink(url) { return true }
        return fm.fileExists(atPath: url.path)
    }

    private func report(path: String, outcome: CopyOutcome) {
        let display = Paths.short(path)
        switch outcome {
        case .copied:
            print("  ✓ \(display)\(dryRun ? "  (dry-run)" : "")")
            linked += 1
        case .linked:
            print("  ↪ \(display)\(dryRun ? "  (dry-run)" : "")")
            linked += 1
        case .skipped(let reason):
            if verbose || (reason != "not found" && reason != "already linked") {
                print("  − \(display)  (\(reason))")
            } else if reason == "already linked" {
                print("  = \(display)  (already linked)")
            }
            skipped += 1
        case .failed(let error):
            FileHandle.standardError.write(Data("  ✗ \(display)  \(error.localizedDescription)\n".utf8))
            failed += 1
        }
    }

    func summary() {
        guard linked + skipped + failed > 0 else { return }
        print()
        var parts: [String] = []
        if linked > 0 { parts.append("Done: \(linked)") }
        if skipped > 0 { parts.append("Skipped: \(skipped)") }
        if failed > 0 { parts.append("Failed: \(failed)") }
        print(parts.joined(separator: "  "))
    }
}
