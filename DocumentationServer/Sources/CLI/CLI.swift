import ArgumentParser
import Hummingbird
import Logging
import DocumentationKit
import DocumentationServer
import DocumentationServerClient



@main
struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        subcommands: [
            RunCommand.self,
            RepoCommand.self,
            PreviewCommand.self
        ]
    )
}


/// Extend `Logger.Level` so it can be used as an argument
#if hasFeature(RetroactiveAttribute)
    extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
    extension Logger.Level: ExpressibleByArgument {}
#endif

import Foundation

