import ArgumentParser
import Foundation

struct EditCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "Open ~/.dotty/<id>.json in $EDITOR."
    )

    @Argument(help: "App identifier, or 'config' to edit ~/.dotty/config.json.")
    var app: String

    func run() throws {
        let target: URL
        if app.lowercased() == "config" {
            target = Paths.configFile
        } else {
            target = Paths.dottyDir.appendingPathComponent("\(app.lowercased()).json")
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: target.path) else {
            FileHandle.standardError.write(Data("\(Paths.short(target.path)) does not exist. Use `dotty add \(app)` to create it.\n".utf8))
            throw ExitCode(1)
        }

        let editor = ProcessInfo.processInfo.environment["EDITOR"]
            ?? ProcessInfo.processInfo.environment["VISUAL"]
            ?? "vi"

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "\(editor) \"\(target.path)\""]
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw ExitCode(task.terminationStatus)
        }
    }
}
