//
//  PreviewDataProvider.swift
//  Docsy
//
//  Created by Noah Kamara on 21.11.24.
//

import DocumentationKit
import Foundation

class PreviewDataProvider: BundleRepositoryProvider {
    static var bundle: PreviewDataProvider = {
        try! PreviewDataProvider(rootPath: Bundle.main.resourcePath!)
    }()
    
    var fileSystem: FSNode
    let provider: DocumentationKit.LocalFileSystemDataProvider
    
    init(
        rootPath: String
    ) throws {
        let rootURL = URL(filePath: rootPath)
        self.provider = try .init(rootURL: rootURL)
        self.fileSystem = try Self.buildTree(root: rootURL)
    }
    
    func data(for path: String) async throws -> Data {
        try await provider.data(for: path)
    }
    
    func bundle(matching identifierOrName: String) -> DocumentationBundle? {
        let term = identifierOrName.lowercased()
        
        return try? findBundles(
            in: fileSystem,
            limit: 1,
            where: {
                $0.identifier.lowercased() == term ||
                $0.displayName.lowercased() == term
            }).first
    }
}

extension PreviewDataProvider {
    /// Builds a virtual file system hierarchy from the contents of a root URL in the local file system.
    /// - Parameter root: The location from which to descend to build the virtual file system.
    /// - Returns: A virtual file system that describe the file and directory structure within the given URL.
    private static func buildTree(root: URL, fileManager: FileManager = .default) throws -> FSNode {
        var children: [FSNode] = []
        let childURLs = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [URLResourceKey.isDirectoryKey],
            options: .skipsHiddenFiles
        )
        
        for url in childURLs {
            if FileManager.default.directoryExists(atPath: url.path) {
                children.append(try buildTree(root: url, fileManager: fileManager))
            } else {
                children.append(FSNode.file(FSNode.File(url: url)))
            }
        }
        
        return FSNode.directory(FSNode.Directory(url: root, children: children))
    }

    func findBundles(
        limit: Int? = nil,
        where  condition: @escaping (DocumentationBundle) -> Bool
    ) throws -> [DocumentationBundle] {
        try findBundles(in: self.fileSystem, limit: limit, where: condition)
    }
    
    private func findBundles(
        in node: FSNode,
        limit: Int? = nil,
        where  condition: @escaping (DocumentationBundle) -> Bool
    ) throws -> [DocumentationBundle] {
        var bundles: [DocumentationBundle] = []
        
        guard case .directory(let directory) = node else {
            preconditionFailure("Expected directory object at path '\(node.url.absoluteString)'.")
        }

        if 
            directory.url.pathExtension == "doccarchive" ||
            directory.children.contains(where: { $0.name == "metadata" })
        {
            let bundle = try createBundle(directory, directory.children)
            return [bundle]
        }
        
        for subdirectory in directory.children.filter(\.isDirectory) {
            let childBundles = try findBundles(in: subdirectory, limit: limit, where: condition)
            bundles.append(contentsOf: childBundles)
            
            if let limit, bundles.count >= limit {
                return bundles
            }
        }
        

        return bundles
    }

    
    enum BundleCreationError: Error {
        case missingMetadata(URL)
        case missingIndex(URL)
    }
    
    /// Creates a documentation bundle from the content in a given documentation bundle directory.
    /// - Parameters:
    ///   - directory: The documentation bundle directory.
    ///   - bundleChildren: The top-level files and directories in the documentation bundle directory.
    ///   - options: Configuration that controls how the provider discovers documentation bundles.
    /// - Throws: A ``WorkspaceError`` if the content is an invalid documentation bundle or
    ///           a ``DocumentationBundle/PropertyListError`` error if the bundle's Info.plist file is invalid.
    /// - Returns: The new documentation bundle.
    private func createBundle(
        _ directory: FSNode.Directory,
        _ bundleChildren: [FSNode]
    ) throws -> DocumentationBundle {
        let metadataFile = bundleChildren
            .firstFile(where: { $0.url.lastPathComponent == "metadata.json" })
        
        guard let metadataFile else {
            throw BundleCreationError.missingMetadata(directory.url)
        }
        
        let metadataData = try provider.contentsOfURL(metadataFile.url)
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(DocumentationBundle.Metadata.self, from: metadataData)
        let themeSettings = bundleChildren
            .firstFile(where: { $0.name == "theme-settings.json" })
        
        guard let indexDir = bundleChildren.firstDirectory(where: { $0.name == "index" }) else {
            throw BundleCreationError.missingIndex(directory.url)
        }
        
        return DocumentationBundle(
            info: metadata,
            indexURL: indexDir.url,
            themeSettingsUrl: themeSettings?.url
        )
    }

}


/// A type that vends a tree of virtual filesystem objects.
public protocol FileSystemProvider {
    /// The organization of the files that this provider provides.
    var fileSystem: FSNode { get }
}

public protocol FSNodeProtocol: CustomStringConvertible {
    var url: URL { get }
}

extension FSNodeProtocol {
    /// The name of the node
    public var name: String { url.lastPathComponent }
    
    /// The base name of the node (without an extension)
    public var baseName: String {
        name.split(separator: ".").dropLast(1).joined()
    }
    
    /// The name of the node
    public var `extension`: String { url.pathExtension }
}

/// An element in a virtual filesystem.
public enum FSNode: FSNodeProtocol, CustomStringConvertible {
    public var description: String {
        switch self {
        case .file(let file):
            file.description
        case .directory(let directory):
            directory.description
        }
    }
    /// A file in a filesystem.
    case file(File)
    /// A directory in a filesystem.
    case directory(Directory)
    
    /// A file in a virtual file system
    public struct File: FSNodeProtocol {
        /// The URL to this file.
        public var url: URL
                
        /// Creates a new virtual file with a given URL
        /// - Parameter url: The URL to this file.
        public init(url: URL) {
            self.url = url
        }
        
        public var description: String {
            "File(\(name))"
        }
    }
    
    /// A directory in a virtual file system.
    public struct Directory: FSNodeProtocol {
        /// The URL to this directory.
        public var url: URL
        
        /// The contents of this directory.
        public var children: [FSNode]
        
        /// Creates a new virtual directory with a given URL and contents.
        /// - Parameters:
        ///   - url: The URL to this directory.
        ///   - children: The contents of this directory.
        public init(url: URL, children: [FSNode]) {
            self.url = url
            self.children = children
        }
        
        public var description: String {
            "Directory(\(name))"
        }
    }
    
    /// The URL for the node in the filesystem.
    public var url: URL {
        switch self {
        case .file(let file):
            return file.url
        case .directory(let directory):
            return directory.url
        }
    }
    
    public var isFile: Bool {
        if case .file = self { true } else { false }
    }
    
    public var isDirectory: Bool {
        !isFile
    }
}

fileprivate extension [FSNode] {
    /// Returns the first file that matches a given predicate.
    /// - Parameter predicate: A closure that takes a file as its argument and returns a Boolean value indicating whether the file should be returned from this function.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first file that matches the predicate.
    func firstFile(where predicate: (FSNode.File) throws -> Bool) rethrows -> FSNode.File? {
        for case .file(let file) in self where try predicate(file) {
            return file
        }
        return nil
    }
    
    /// Returns the first directory that matches a given predicate.
    /// - Parameter predicate: A closure that takes a directory as its argument and returns a Boolean value indicating whether the file should be returned from this function.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first directory that matches the predicate.
    func firstDirectory(where predicate: (FSNode.Directory) throws -> Bool) rethrows -> FSNode.Directory? {
        for case .directory(let directory) in self where try predicate(directory) {
            return directory
        }
        return nil
    }
    
    /// Returns all the files that match s given predicate.
    /// - Parameters:
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories in the array.
    ///   - predicate: A closure that takes a file as its argument and returns a Boolean value indicating whether the file should be included in the returned array.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first file that matches the predicate.
    func files(recursive: Bool, where predicate: (FSNode.File) throws -> Bool) rethrows -> [FSNode.File] {
        var matches: [FSNode.File] = []
        
        for node in self {
            switch node {
            case .directory(let directory):
                guard recursive else { break }
                try matches.append(contentsOf: directory.children.files(recursive: true, where: predicate))
            case .file(let file) where try predicate(file):
                matches.append(file)
            case .file:
                break
            }
        }
        
        return matches
    }
    
    func directories() -> [FSNode.Directory] {
        compactMap({ node in
            if case .directory(let directory) = node { directory } else { nil }
        })
    }
    
    func files() -> [FSNode.File] {
        compactMap({ node in
            if case .file(let file) = node { file } else { nil }
        })
    }
}

extension FSNode {
    /// Creates an array with the tree data formatted in a readable way.
    public func treeLines(
        _ nodeIndent: String = "",
        _ childIndent: String = ""
    ) -> [String] {
        let initial = [ nodeIndent + name + (isDirectory ? "/" : "") ]
        
        if case .directory(let directory) = self {
            let addition = directory.children.enumerated().map { ($0 < directory.children.count-1, $1) }
                .flatMap { $0 ? $1.treeLines("┣╸","┃ ") : $1.treeLines("┗╸","  ") }
                .map { childIndent + $0 }
            
            return initial + addition
        }
        
        return initial
    }
    
    /// Dumps the tree data into a `String` in a human readable way.
    public func dumpTree() -> String {
        return treeLines().joined(separator:"\n")
    }
}
