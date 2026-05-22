import ArgumentParser
import Foundation

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add an app schema to ~/.dotty/. Uses a bundled template if available, otherwise offers to scaffold a blank schema."
    )

    @Argument(help: "App identifier (see `dotty schemas`).")
    var app: String

    @Flag(name: .long, help: "Overwrite an existing ~/.dotty/<id>.json file.")
    var refresh: Bool = false

    func run() throws {
        let id = app.lowercased()
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.dottyDir, withIntermediateDirectories: true)
        let url = Paths.dottyDir.appendingPathComponent("\(id).json")

        if fm.fileExists(atPath: url.path) && !refresh {
            FileHandle.standardError.write(Data("\(Paths.short(url.path)) already exists. Use --refresh to overwrite.\n".utf8))
            throw ExitCode(1)
        }

        if let schema = SchemaRegistry.bundledBuiltins().first(where: { $0.id == id }) {
            try SchemaWriter.write(schema, to: url)
            print("Wrote \(Paths.short(url.path)) from bundled template.")
            return
        }

        if !Confirmation.ask("No bundled schema for '\(id)'. Create a blank schema?", defaultYes: true) {
            print("Aborted. Run `dotty schemas` to see available templates.")
            return
        }
        try SchemaSetup.writeBlankSchema(id: id, to: url)
        print("Wrote blank \(Paths.short(url.path)).")

        if Confirmation.ask("Open it in $EDITOR now?", defaultYes: true) {
            try Editor.open(url)
        }
    }
}

enum SchemaWriter {
    static func write(_ schema: AppSchema, to url: URL) throws {
        try SchemaSetup.writeSchema(schema, to: url)
    }
}

enum Editor {
    static func open(_ url: URL) throws {
        let editor = ProcessInfo.processInfo.environment["EDITOR"]
            ?? ProcessInfo.processInfo.environment["VISUAL"]
            ?? "vi"
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "\(editor) \"\(url.path)\""]
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw ExitCode(task.terminationStatus)
        }
    }
}
