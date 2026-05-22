import ArgumentParser
import Foundation

struct EditCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "Open ~/.dotty/<id>.json in $EDITOR. Offers to scaffold a blank schema if missing."
    )

    @Argument(help: "App identifier, or 'config' to edit ~/.dotty/config.json.")
    var app: String

    func run() throws {
        let isRootConfig = app.lowercased() == "config"
        let target: URL = isRootConfig
            ? Paths.configFile
            : Paths.dottyDir.appendingPathComponent("\(app.lowercased()).json")

        let fm = FileManager.default
        if !fm.fileExists(atPath: target.path) {
            if isRootConfig {
                FileHandle.standardError.write(Data("\(Paths.short(target.path)) does not exist. Run `dotty init` first.\n".utf8))
                throw ExitCode(1)
            }
            if !Confirmation.ask("\(Paths.short(target.path)) does not exist. Create a blank schema?", defaultYes: true) {
                print("Aborted.")
                return
            }
            try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)
            try SchemaSetup.writeBlankSchema(id: app.lowercased(), to: target)
            print("Wrote blank \(Paths.short(target.path)).")
        }

        try Editor.open(target)
    }
}
