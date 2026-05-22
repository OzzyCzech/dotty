import Foundation

enum SyncOperation {
    case snapshot   // home → destination, always copy (ignores strategy)
    case adopt      // home → destination, per strategy (move+symlink for link paths)
    case deploy     // destination → home, per strategy
}

final class SyncEngine {
    private let fm = FileManager.default
    private let dryRun: Bool
    private let verbose: Bool

    var copied = 0
    var linked = 0
    var skipped = 0
    var failed = 0

    init(dryRun: Bool = false, verbose: Bool = false) {
        self.dryRun = dryRun
        self.verbose = verbose
    }

    func run(operation: SyncOperation, schema: AppSchema, backupDir: URL) {
        print(schema.name)
        if operation != .deploy, !dryRun {
            try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        for spec in schema.paths {
            let effective: SyncStrategy = (operation == .snapshot)
                ? .copy
                : spec.resolvedStrategy(default: schema.strategy)
            let src = URL(fileURLWithPath: Paths.expand(spec.source))
            let backup = backupDir.appendingPathComponent(spec.resolvedTarget())
            let outcome: CopyOutcome
            switch effective {
            case .link:
                outcome = ensureLink(source: src, backup: backup, operation: operation)
            case .copy:
                outcome = (operation == .deploy)
                    ? copyOne(from: backup, to: src)
                    : copyOne(from: src, to: backup)
            }
            report(path: src.path, outcome: outcome, strategy: effective)
        }
    }

    private func copyOne(from src: URL, to dest: URL) -> CopyOutcome {
        guard fm.fileExists(atPath: src.path) else {
            return .skipped(reason: "not found")
        }
        if dryRun { return .copied }
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) || isSymlink(dest) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: src, to: dest)
            return .copied
        } catch {
            return .failed(error)
        }
    }

    private func ensureLink(source: URL, backup: URL, operation: SyncOperation) -> CopyOutcome {
        let srcIsSymlink = isSymlink(source)
        let srcExistsReal = !srcIsSymlink && fm.fileExists(atPath: source.path)
        let backupExists = fm.fileExists(atPath: backup.path)

        // Already linked correctly → no-op
        if srcIsSymlink, let dest = try? fm.destinationOfSymbolicLink(atPath: source.path) {
            let resolved = URL(fileURLWithPath: dest, relativeTo: source.deletingLastPathComponent()).standardizedFileURL
            if resolved.path == backup.standardizedFileURL.path {
                return .skipped(reason: "already linked")
            }
        }

        switch (srcExistsReal, backupExists, operation) {
        case (false, true, _):
            return createSymlink(at: source, target: backup)
        case (true, false, .adopt):
            if dryRun { return .linked }
            do {
                try fm.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: source, to: backup)
                return createSymlink(at: source, target: backup)
            } catch {
                return .failed(error)
            }
        case (true, false, .deploy):
            return .skipped(reason: "destination empty — run `dotty adopt` first")
        case (true, false, .snapshot):
            // Snapshot for link strategy shouldn't happen (we forced strategy=.copy)
            return .skipped(reason: "unexpected")
        case (true, true, _):
            return .skipped(reason: "conflict: both source and destination exist; resolve manually")
        case (false, false, _):
            if srcIsSymlink { return .skipped(reason: "broken symlink") }
            return .skipped(reason: "not found")
        }
    }

    private func createSymlink(at source: URL, target: URL) -> CopyOutcome {
        if dryRun { return .linked }
        do {
            try fm.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
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

    private func report(path: String, outcome: CopyOutcome, strategy: SyncStrategy) {
        let display = Paths.short(path)
        let tag = dryRun ? "  \(Ansi.dim("(dry-run)"))" : ""
        switch outcome {
        case .copied:
            print("  \(Ansi.green("✓")) \(display)\(tag)")
            copied += 1
        case .linked:
            print("  \(Ansi.cyan("↪")) \(display)\(tag)")
            linked += 1
        case .skipped(let reason):
            if verbose || (reason != "not found" && reason != "already linked") {
                print("  \(Ansi.dim("−")) \(display)  \(Ansi.dim("(\(reason))"))")
            } else if reason == "already linked" {
                print("  \(Ansi.dim("=")) \(display)  \(Ansi.dim("(already linked)"))")
            }
            skipped += 1
        case .failed(let error):
            FileHandle.standardError.write(Data("  \(Ansi.yellow("✗")) \(display)  \(error.localizedDescription)\n".utf8))
            failed += 1
        }
    }

    func summary() {
        guard copied + linked + skipped + failed > 0 else { return }
        print()
        var parts: [String] = []
        if copied > 0 { parts.append("Copied: \(copied)") }
        if linked > 0 { parts.append("Linked: \(linked)") }
        if skipped > 0 { parts.append("Skipped: \(skipped)") }
        if failed > 0 { parts.append("Failed: \(failed)") }
        print(Ansi.dim(parts.joined(separator: "  ")))
    }
}
