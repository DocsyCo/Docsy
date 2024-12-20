//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import Foundation
import ArgumentParser
import DocumentationServerClient

struct ServerOptions: ParsableArguments {
    @Flag(help: "run server before executing the command. (see 'Options' below)")
    var run: Bool = false

    @OptionGroup(title: "Run Options")
    var config: RunConfiguration
    
    var baseURI: URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = config.hostname
        components.port = config.port
        return components.url!
    }
    
    func task(timeout: Duration = .seconds(5)) async throws -> Task<Void, any Error> {
        let runServerTask = Task {
            if run {
                print("booting server at \(baseURI)")
                try await runServer(config: config)
            }
        }
        
        let healthCheck = HealthCheck(baseURI: baseURI)
        
        try await withTimeout(seconds: run ? 10 : 1) {
            print("trying to reach server at \(baseURI)")
            
            for await isHealthy in healthCheck {
                if isHealthy {
                    print("found server")
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        
        return runServerTask
    }
    
    func repository() -> HTTPDocumentationRepository {
        HTTPDocumentationRepository(baseURI: baseURI)
    }
}

struct ConsoleError: Error {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
}


struct HealthCheck: AsyncSequence {
    typealias Element = Bool
    
    let baseURI: URL
    let interval: TimeInterval
    
    init(baseURI: URL, interval: TimeInterval = 5.0) {
        self.baseURI = baseURI
        self.interval = interval
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(baseURI: baseURI, interval: interval)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        let baseURI: URL
        let interval: TimeInterval
        
        func next() async -> Bool? {
            while true {
                do {
                    let statusURL = baseURI.appendingPathComponent("status")
                    let (_, response) = try await URLSession.shared.data(from: statusURL)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        return httpResponse.statusCode == 200
                    }
                } catch {
                    return false
                }
                
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
}
