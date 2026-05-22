import ArgumentParser

@main
struct Dotty: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotty",
        abstract: "Back up, restore, and sync application config files.",
        version: "0.5.0",
        subcommands: [
            InitCommand.self,
            AddCommand.self,
            RemoveCommand.self,
            EditCommand.self,
            ListCommand.self,
            TemplatesCommand.self,
            DoctorCommand.self,
            SaveCommand.self,
            RestoreCommand.self,
        ]
    )
}
