import ArgumentParser

@main
struct Dotty: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotty",
        abstract: "Back up, restore, and sync application config files.",
        version: "0.2.0",
        subcommands: [
            InitCommand.self,
            ListCommand.self,
            DoctorCommand.self,
            BackupCommand.self,
            RestoreCommand.self,
            LinkCommand.self,
            UnlinkCommand.self,
        ]
    )
}
