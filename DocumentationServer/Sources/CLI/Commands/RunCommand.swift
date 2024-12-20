//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import ArgumentParser
import Logging
import Hummingbird
import DocumentationServer
import DocumentationKit

struct RunCommand: AsyncParsableCommand {
    @OptionGroup
    var config: RunConfiguration
    
//    @Option(name: .shortAndLong, completion: .file())
//    var envFile: String = ".env"

    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "run documentation server"
    )
    
    func run() async throws {
        try await runServer(config: config)
    }
}

func runServer(config: RunConfiguration) async throws {
    let configuration = await config.configuration()
    
    let server = DocumentationServer(configuration: configuration)
    
    // Repository
    let documentationRepository = InMemoryDocumentationRepository()

    let repository = RepositoryService(repository: documentationRepository)
    await server.registerService(repository)
    
    try await server.run()
}



struct RunConfiguration: ParsableArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = 1234

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level = .info
    
    @Flag(name: .long)
    var inMemory: Bool = false
    
    func configuration() async -> DocumentationServer.Configuration {
        var env = Environment()
        if let dotEnv = try? await Environment.dotEnv() {
            env = env.merging(with: dotEnv)
        }
        return .init(hostname: hostname, port: port, logLevel: logLevel)
    }
}
