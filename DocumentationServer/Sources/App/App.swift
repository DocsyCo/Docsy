import ArgumentParser
import Hummingbird
import Logging

@main
struct AppCommand: AsyncParsableCommand, AppArguments {
    @Flag(name: .long)
    var inMemory: Bool = false

    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 1234

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level?

    func run() async throws {
        var env = Environment()
        
        if env.get("POSTGRES_HOST") == nil {
            print("Attempting to load from .env")
            let dotenv = try await Environment.dotEnv()
            env = env.merging(with: dotenv)
        }
        

        let app = try await buildApplication(self)
        
        try await app.runService()
    }
}



/// Extend `Logger.Level` so it can be used as an argument
#if hasFeature(RetroactiveAttribute)
    extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
    extension Logger.Level: ExpressibleByArgument {}
#endif
