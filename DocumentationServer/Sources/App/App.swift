import ArgumentParser
import Hummingbird
import Logging
import DocumentationKit
import DocumentationServer


@main
struct AppCommand: AsyncParsableCommand {
    @Flag(name: .long)
    var inMemory: Bool = false

    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 1234

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level?
    
    @Option(name: .shortAndLong, completion: .file())
    var envFile: String = ".env"

    func run() async throws {
        var env = Environment()
        if let dotEnv = try? await Environment.dotEnv() {
            env = env.merging(with: dotEnv)
        }

        let configuration = DocumentationServer.Configuration(
            hostname: hostname,
            port: port,
            logLevel: logLevel ?? .info
        )
        
        let server = DocumentationServer(configuration: configuration)
        
        // Repository
        let documentationRepository = InMemoryDocumentationRepository()
        let repository = RepositoryService(repository: documentationRepository)
        await server.registerService(repository)
        
        try await server.run()
    }
}



/// Extend `Logger.Level` so it can be used as an argument
#if hasFeature(RetroactiveAttribute)
    extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
    extension Logger.Level: ExpressibleByArgument {}
#endif
