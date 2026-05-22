import ArgumentParser

@main
struct Dotty: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotty",
        abstract: "Back up, restore, and sync application config files.",
        version: "0.4.0",
        subcommands: [
            InitCommand.self,
            ListCommand.self,
            DoctorCommand.self,
            SaveCommand.self,
            RestoreCommand.self,
        ]
    )
}
