import Foundation

enum Paths {
    static let home = (NSString(string: "~").expandingTildeInPath as NSString).standardizingPath

    static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    static func short(_ absolute: String) -> String {
        let abs = (absolute as NSString).standardizingPath
        if abs.hasPrefix(home) {
            let suffix = String(abs.dropFirst(home.count))
            return "~" + (suffix.hasPrefix("/") ? suffix : "/" + suffix)
        }
        return abs
    }

    static func relativeToBackupRoot(absolute: String) -> String {
        let abs = (absolute as NSString).standardizingPath
        if abs.hasPrefix(home) {
            let suffix = String(abs.dropFirst(home.count))
            return suffix.hasPrefix("/") ? String(suffix.dropFirst(1)) : suffix
        }
        return abs.hasPrefix("/") ? String(abs.dropFirst(1)) : abs
    }

    static var dottyDir: URL {
        URL(fileURLWithPath: home).appendingPathComponent(".dotty")
    }

    static var configFile: URL {
        dottyDir.appendingPathComponent("config.json")
    }

    static var defaultBackupDir: URL {
        dottyDir.appendingPathComponent("backup")
    }

    /// Display string for ~/.dotty showing the resolved location when it is a
    /// symlink. Returns just the short path when it isn't, or doesn't exist yet.
    static func dottyDirDisplay() -> String {
        let dotty = dottyDir
        let resolved = dotty.resolvingSymlinksInPath()
        if resolved.path == dotty.path {
            return short(dotty.path)
        }
        return "\(short(dotty.path)) → \(short(resolved.path))"
    }
}
