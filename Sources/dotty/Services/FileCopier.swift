import Foundation

final class FileCopier {
    private let fm = FileManager.default
    private let dryRun: Bool
    private let verbose: Bool

    var copied = 0
    var skipped = 0
    var failed = 0

    init(dryRun: Bool = false, verbose: Bool = false) {
        self.dryRun = dryRun
        self.verbose = verbose
    }

    func backup(schema: AppSchema, backupDir: URL) {
        printHeader(schema.name)
        if !dryRun {
            try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        for path in schema.paths {
            let src = URL(fileURLWithPath: Paths.expand(path))
            let dest = backupDir.appendingPathComponent(Paths.relativeToBackupRoot(absolute: src.path))
            report(path: src.path, outcome: copy(from: src, to: dest, requireSource: true))
        }
    }

    func restore(schema: AppSchema, backupDir: URL) {
        printHeader(schema.name)
        for path in schema.paths {
            let dest = URL(fileURLWithPath: Paths.expand(path))
            let src = backupDir.appendingPathComponent(Paths.relativeToBackupRoot(absolute: dest.path))
            report(path: dest.path, outcome: copy(from: src, to: dest, requireSource: true))
        }
    }

    private func copy(from src: URL, to dest: URL, requireSource: Bool) -> CopyOutcome {
        guard fm.fileExists(atPath: src.path) else {
            return .skipped(reason: "not found")
        }
        if dryRun {
            return .copied
        }
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: src, to: dest)
            return .copied
        } catch {
            return .failed(error)
        }
    }

    private func printHeader(_ name: String) {
        print(name)
    }

    private func report(path: String, outcome: CopyOutcome) {
        let display = Paths.short(path)
        switch outcome {
        case .copied:
            print("  ✓ \(display)\(dryRun ? "  (dry-run)" : "")")
            copied += 1
        case .linked:
            print("  ↪ \(display)")
            copied += 1
        case .skipped(let reason):
            if verbose || reason != "not found" {
                print("  − \(display)  (\(reason))")
            }
            skipped += 1
        case .failed(let error):
            FileHandle.standardError.write(Data("  ✗ \(display)  \(error.localizedDescription)\n".utf8))
            failed += 1
        }
    }

    func summary() {
        guard copied + skipped + failed > 0 else { return }
        print()
        var parts: [String] = []
        if copied > 0 { parts.append("Copied: \(copied)") }
        if skipped > 0 { parts.append("Skipped: \(skipped)") }
        if failed > 0 { parts.append("Failed: \(failed)") }
        print(parts.joined(separator: "  "))
    }
}
