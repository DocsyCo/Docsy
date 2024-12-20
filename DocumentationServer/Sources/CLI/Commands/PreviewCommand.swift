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
        
        let provider = try LocalFileSystemDataProvider(
            rootURL: URL(filePath: rootDir, directoryHint: .isDirectory),
            allowArbitraryCatalogDirectories: true
        )
        
        print("importing bundles")
        let bundles = try provider.bundles()
        
        let runTask = try await serverOptions.task()
        
        let server = serverOptions.repository()
        
        for bundleInfo in bundles {
            let bundle = try await server.addBundle(
                at: bundleInfo.baseURL.path(),
                displayName: bundleInfo.displayName,
                identifier: bundleInfo.identifier,
                tag: "latest"
            )
            
            print(
                """
                Added Bundle:
                  id=\(bundle.id.uuidString)
                  displayName='\(bundle.metadata.displayName)'
                  bundleIdentifier='\(bundle.metadata.bundleIdentifier)'
                """
            )
        }
        
        print("finished importing documentation. server is running.")
        try await runTask.value
    }
}
