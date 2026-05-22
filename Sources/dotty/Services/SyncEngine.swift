import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum SyncOperation {
    case link       // ensure home reflects destination via symlinks (move-or-link state machine)
    case snapshot   // pure copy home → destination
}

enum ConflictPreference: String, CaseIterable {
    case home          // home version wins; overwrite destination, then symlink
    case destination   // destination version wins; overwrite home, then symlink
}

final class SyncEngine {
    private let fm = FileManager.default
    private let dryRun: Bool
    private let verbose: Bool
    private let prefer: ConflictPreference?

    var copied = 0
    var linked = 0
    var skipped = 0
    var failed = 0

    init(dryRun: Bool = false, verbose: Bool = false, prefer: ConflictPreference? = nil) {
        self.dryRun = dryRun
        self.verbose = verbose
        self.prefer = prefer
    }

    func run(operation: SyncOperation, schema: AppSchema, destinationDir: URL) {
        print(schema.name)
        if !dryRun {
            try? fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        }
        for spec in schema.paths {
            let src = URL(fileURLWithPath: Paths.expand(spec.source))
            let dest = destinationDir.appendingPathComponent(spec.resolvedTarget())
            let outcome: CopyOutcome
            switch operation {
            case .link:
                outcome = ensureLink(source: src, destination: dest)
            case .snapshot:
                outcome = snapshotOne(src: src, dest: dest)
            }
            report(path: src.path, outcome: outcome)
        }
    }

    // MARK: - link operation (state machine)

    private func ensureLink(source: URL, destination: URL) -> CopyOutcome {
        let srcIsSymlink = isSymlink(source)
        let destExists = fm.fileExists(atPath: destination.path)

        // Source is a symlink — inspect where it points.
        if srcIsSymlink {
            guard let target = try? fm.destinationOfSymbolicLink(atPath: source.path) else {
                return .skipped(reason: "unreadable symlink")
            }
            let resolvedTarget = URL(fileURLWithPath: target, relativeTo: source.deletingLastPathComponent()).standardizedFileURL
            if resolvedTarget.path == destination.standardizedFileURL.path {
                return .skipped(reason: "already linked")
            }
            if !fm.fileExists(atPath: resolvedTarget.path) {
                return .skipped(reason: "broken symlink → \(target)")
            }
            return .skipped(reason: "symlink points elsewhere → \(Paths.short(resolvedTarget.path)); resolve manually")
        }

        let srcExistsReal = fm.fileExists(atPath: source.path)
        switch (srcExistsReal, destExists) {
        case (false, true):
            return createSymlink(at: source, target: destination)
        case (true, false):
            // Bootstrap: move home file → destination, then symlink.
            if dryRun { return .linked }
            do {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: source, to: destination)
                return createSymlink(at: source, target: destination)
            } catch {
                return .failed(error)
            }
        case (true, true):
            switch prefer {
            case .destination:
                // Home file is discarded; symlink takes its place.
                return createSymlink(at: source, target: destination)
            case .home:
                // Destination is replaced with home content; then symlink.
                if dryRun { return .linked }
                do {
                    try fm.removeItem(at: destination)
                    try fm.moveItem(at: source, to: destination)
                    return createSymlink(at: source, target: destination)
                } catch {
                    return .failed(error)
                }
            case nil:
                return .skipped(reason: "conflict: both home and destination have content; rerun with --prefer home or --prefer destination")
            }
        case (false, false):
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

    // MARK: - snapshot operation (pure copy home → destination)

    private func snapshotOne(src: URL, dest: URL) -> CopyOutcome {
        guard fm.fileExists(atPath: src.path) else {
            return .skipped(reason: "not found")
        }
        // Safety: if src resolves to the same file as dest (src is a symlink already pointing
        // at dest), refuse to delete-then-copy. POSIX realpath follows symlink leaves.
        if let srcResolved = resolvedPath(src),
           let destResolved = resolvedPath(dest),
           srcResolved == destResolved {
            return .skipped(reason: "already in place")
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

    private func resolvedPath(_ url: URL) -> String? {
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard realpath(url.path, &buf) != nil else { return nil }
        return String(cString: buf)
    }

    private func isSymlink(_ url: URL) -> Bool {
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        return (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    // MARK: - reporting

    private func report(path: String, outcome: CopyOutcome) {
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
            let quiet = reason == "not found" || reason == "already linked" || reason == "already in place"
            if verbose || !quiet {
                print("  \(Ansi.dim("−")) \(display)  \(Ansi.dim("(\(reason))"))")
            } else if reason == "already linked" || reason == "already in place" {
                print("  \(Ansi.dim("=")) \(display)  \(Ansi.dim("(\(reason))"))")
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
