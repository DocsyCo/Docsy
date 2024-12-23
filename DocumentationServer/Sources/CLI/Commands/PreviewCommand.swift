//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import Foundation
import ArgumentParser
import DocumentationKit

struct PreviewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Preview documentation"
    )
    
    @Argument(help: "The root directory to search for documentation bundles", completion: .directory)
    var rootDir: String
    
    @OptionGroup(title: "Server Options")
    var serverOptions: ServerOptions
    
    mutating func run() async throws {
        serverOptions.run = true
        
        let rootURL = URL(filePath: rootDir, directoryHint: .isDirectory)
        let provider = try LocalFileSystemDataProvider(
            rootURL: rootURL,
            allowArbitraryCatalogDirectories: true
        )
        
        print("importing bundles")
        let bundles = try provider.bundles()
        
        let runTask = try await serverOptions.task()
        
        let server = serverOptions.repository()
        
        let fileServer = PreviewFileServer(
            rootFolder: rootDir,
            hostname: serverOptions.config.hostname,
            port: serverOptions.config.port + 1
        )
        
        for bundleInfo in bundles {
            let sourcePath = serverOptions.baseURI
                .appending(path: bundleInfo.baseURL.absoluteURL.path())
                .path()
                .trimmingPrefix(rootURL.absoluteURL.path())
                .trimmingSuffix(while: { $0 == "/" })
            
            let source = fileServer.baseURI.appending(path: sourcePath).absoluteURL

            let bundle = try await server.addBundle(
                at: bundleInfo.baseURL.path(),
                displayName: bundleInfo.displayName,
                identifier: bundleInfo.identifier,
                source: source,
                tag: "latest"
            )
            
            print(
                """
                Added Bundle:
                  id=\(bundle.id.uuidString)
                  displayName='\(bundle.metadata.displayName)'
                  bundleIdentifier='\(bundle.metadata.bundleIdentifier)'
                  source='\(source)'
                """
            )
        }
        
        
        let fileServerTask = Task { try await fileServer.run() }
        defer { fileServerTask.cancel() }
        
        
        print("\n\nfinished importing documentation. server is running.")
        print("API: \(serverOptions.baseURI)")
        print("Fileserver: \(serverOptions.baseURI)")
        
        try await runTask.value
    }
}

import Hummingbird

struct PreviewFileServer: ~Copyable {
    let rootFolder: String
    let hostname: String
    let port: Int
    
    var baseURI: URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = hostname
        components.port = port
        return components.url!
    }
    
    init(rootFolder: String, hostname: String, port: Int) {
        self.rootFolder = rootFolder
        self.hostname = hostname
        self.port = port
    }
    
    func run() async throws {
        let router = Router()
                
        router.addMiddleware {
            // Log requests
            LogRequestsMiddleware(.info)
            
            // Serve files from the specified directory
            FileMiddleware(
                fileProvider: LocalFileSystem(
                    rootFolder: rootFolder,
                    threadPool: .singleton,
                    logger: .init(label: "Storage")
                ),
                searchForIndexHtml: true
            )
        }
                
        let app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        try await app.runService()
    }
}
