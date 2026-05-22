import ArgumentParser

@main
struct Dotty: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotty",
        abstract: "Back up, restore, and sync application config files.",
        version: "0.7.1",
        subcommands: [
            InitCommand.self,
            ReinitCommand.self,
            AddCommand.self,
            RemoveCommand.self,
            EditCommand.self,
            ListCommand.self,
            SchemasCommand.self,
            DoctorCommand.self,
            SnapshotCommand.self,
            AdoptCommand.self,
            DeployCommand.self,
        ]
    )
}
