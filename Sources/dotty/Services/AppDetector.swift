import Foundation

enum AppDetector {
    static func isInstalled(_ schema: AppSchema) -> Bool {
        let fm = FileManager.default
        return schema.paths.contains { spec in
            fm.fileExists(atPath: Paths.expand(spec.source))
        }
    }
}
