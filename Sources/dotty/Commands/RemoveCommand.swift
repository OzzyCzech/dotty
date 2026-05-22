import ArgumentParser
import Foundation

struct RemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Delete ~/.dotty/<id>.json. Does not touch home files or the backup."
    )

    @Argument(help: "App identifier.")
    var app: String

    @Flag(name: .long, help: "Skip the confirmation prompt.")
    var force: Bool = false

    func run() throws {
        let id = app.lowercased()
        let url = Paths.dottyDir.appendingPathComponent("\(id).json")
        let fm = FileManager.default

        guard fm.fileExists(atPath: url.path) else {
            FileHandle.standardError.write(Data("\(Paths.short(url.path)) does not exist.\n".utf8))
            throw ExitCode(1)
        }

        if !force {
            if !Confirmation.ask("Delete \(Paths.short(url.path))?") {
                print("Aborted.")
                return
            }
        }

        try fm.removeItem(at: url)
        print("Removed \(Paths.short(url.path))")
    }
}
