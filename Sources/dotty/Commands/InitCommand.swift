import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create ~/.dotty/config.json with defaults."
    )

    @Option(name: .long, help: "Backup destination directory.")
    var destination: String = DottyConfig.defaultDestination

    @Flag(name: .long, help: "Overwrite existing config without prompting.")
    var force: Bool = false

    func run() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)
        let url = Paths.configFile

        if fm.fileExists(atPath: url.path) && !force {
            if !Confirmation.ask("\(Paths.short(url.path)) exists. Overwrite?") {
                print("Aborted.")
                return
            }
        }

        let payload: [String: Any] = ["destination": destination]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
        print("Wrote \(Paths.short(url.path))")
    }
}
