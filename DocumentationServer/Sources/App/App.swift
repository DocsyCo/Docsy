import ArgumentParser
import Hummingbird
import Logging
import DocumentationKit
import DocumentationServer


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
    
    @Option(name: .shortAndLong, completion: .file())
    var envFile: String = ".env"

    func run() async throws {
        var env = Environment()
        if let dotEnv = try? await Environment.dotEnv() {
            env = env.merging(with: dotEnv)
        }

//        let app = try await buildApplication(self)
//        
//        try await app.runService()
//        let server = DocumentationServer.
//
//        let documentationRepository = InMemoryDocumentationRepository()
//        let repository = RepositoryService(repository: documentationRepository)
//        await server.registerService(repository)
        
//        server.run()
    }
}



/// Extend `Logger.Level` so it can be used as an argument
#if hasFeature(RetroactiveAttribute)
    extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
    extension Logger.Level: ExpressibleByArgument {}
#endif
