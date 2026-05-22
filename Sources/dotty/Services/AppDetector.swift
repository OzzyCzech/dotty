import Foundation

enum AppDetector {
    static func isInstalled(_ schema: AppSchema) -> Bool {
        let fm = FileManager.default
        return schema.paths.contains { path in
            fm.fileExists(atPath: Paths.expand(path))
        }
    }
}
