import ArgumentParser

@main
struct Dotty: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotty",
        abstract: "Manage dotfiles with symlinks to a destination directory (typically a git repo).",
        version: "0.8.1",
        subcommands: [
            InitCommand.self,
            ReinitCommand.self,
            AddCommand.self,
            RemoveCommand.self,
            EditCommand.self,
            ListCommand.self,
            SchemasCommand.self,
            DoctorCommand.self,
            LinkCommand.self,
            SnapshotCommand.self,
        ]
    )
}
