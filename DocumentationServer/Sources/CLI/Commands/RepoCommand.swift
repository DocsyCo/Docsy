//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import Foundation
import ArgumentParser
import DocumentationKit



struct RepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repo",
        abstract: "use repository",
        subcommands: [
            AddBundleRepoCommand.self,
            ImportBundlesRepoCommand.self
        ]
    )
}

// MARK: Add Bundle
fileprivate struct AddBundleRepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add")
    
    @Argument(
        help: "the path to a documentation archive",
        completion: .file(extensions: ["doccarchive"])
    )
    var archive: String?
    
    @Option(help: "overrides the 'display name' for this bundle")
    var displayName: String?
    
    @Option(help: "overrides the 'bundleIdentifier' for this bundle")
    var identifier: String?
    
    @Option(help: "sets the revisions unique 'tag'")
    var tag: String = "latest"
    
    @OptionGroup(title: "Server Options")
    var server: ServerOptions
    
    func run() async throws {
        guard archive != nil || (displayName != nil && identifier != nil) else {
            throw ConsoleError("specify either archive, or displayName AND identifier")
        }
        
        let runTask = try await server.task()
        defer { runTask.cancel() }
        let server = server.repository()
        
        var displayName = displayName
        var identifier = identifier
        
        if let archive, (displayName == nil || identifier == nil) {
            let provider = try LocalFileSystemDataProvider(
                rootURL: URL(filePath: archive),
                allowArbitraryCatalogDirectories: true
            )
            
            guard let bundle = try provider.bundles().first else {
                throw ConsoleError("Could not find bundle at \(archive)")
            }
            
            if displayName == nil {
                displayName = bundle.metadata.displayName
            }
            
            if identifier == nil {
                identifier = bundle.metadata.identifier
            }
        }
        
        let bundle = try await server.addBundle(
            at: archive,
            displayName: displayName,
            identifier: identifier,
            tag: tag
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
}

// MARK: Import
fileprivate struct ImportBundlesRepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "import")
    
    @Argument(
        help: "a directory to search for doccarchive bundles",
        completion: .directory
    )
    var searchDir: String?
    
    
    func isValid() -> Bool {
        searchDir != nil
    }
    
    @Option(help: "sets the revisions unique 'tag'")
    var tag: String = "latest"
    
    @OptionGroup(title: "Server Options")
    var server: ServerOptions
    
    func run() async throws {
        guard let searchDir = searchDir else {
            return
        }
        
        let provider = try LocalFileSystemDataProvider(
            rootURL: URL(filePath: searchDir, directoryHint: .isDirectory),
            allowArbitraryCatalogDirectories: true
        )
        print("importing bundles")
        let bundles = try provider.bundles()
        
        let runTask = try await server.task()
        defer { runTask.cancel() }
        let server = server.repository()
        
        for bundleInfo in bundles {
            let bundle = try await server.addBundle(
                at: bundleInfo.baseURL.path(),
                displayName: bundleInfo.displayName,
                identifier: bundleInfo.identifier,
                tag: tag
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
    }
}


