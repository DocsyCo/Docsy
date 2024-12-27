//
//  Workspace.swift
//  Docsy
//
//  Copyright © 2024 Noah Kamara.
//

import DocumentationKit
import Foundation

import DocumentationKit
import OSLog

extension Logger {
    static func docsee(_ category: String) -> Logger {
        Logger(subsystem: "com.noahkamara.docsee", category: category)
    }
}

public class DocumentationWorkspace: DocumentationContext2 {
    private let logger: Logger = .docsee("workspace")
    private let bundles = BundleRepository()
    
    
    func addDocumentation(_ bundle: DocumentationBundle, with provider: BundleRepositoryProvider) async {
        await bundles.registerBundle(bundle, withProvider: provider)
    }
    
    func removeDocumentation(_ bundleId: DocumentationBundle.ID) async {
        await bundles.unregisterBundle(with: bundleId)
    }
}

public protocol DocumentationContext2 {
//    func contentsOfPath(_ path: String, in bundle: DocumentationBundle) throws -> Data
}

public class Workspace {
    let logger: Logger = .docsee("workspace")

    
    // MARK: Sub Models
    let bundleRepository: BundleRepository = .init()
    let metadata: WorkspaceMetadata = .init()
    let navigator: Navigator = .init()

    // MARK: Options

    private let config: Configuration
    private let fileManager: FileManager

    // MARK: Project

    private var project: Project
    private(set) var search: SearchIndex

    init(
        config: Configuration = .init(),
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.config = config
        self.project = .scratchpad()

        let search = try loadSearchIndex(
            config: config,
            projectId: project.identifier,
            fileManager: fileManager
        )
        self.search = search
    }
}

// MARK: Project Management

extension Workspace {
    private var plugins: [DocumentationContextPlugin] {
        [metadata, navigator]
    }

    func save() async throws {
        let project = project

        logger.info("[\(project)] saving project")
        guard project.isPersistent else { return }

        for plugin in plugins {
            try await plugin.willSave(project)
        }

        try project.validate()

        try await project.persist()
    }

    func open(_ newProject: Project, saveCurrent: Bool = true) async throws {
        logger.info("[open] opening \(newProject)")
        do {
            try newProject.validate()
        } catch {
            logger.error("[open] '\(newProject)' failed validation: \(error)")
            throw error
        }

        if saveCurrent {
            try await save()
        }

        // Register Bundles
        logger.debug("[open] unregistering bundles")
        await bundleRepository.unregisterAll()

        logger.debug("[open] register bundles for \(newProject)")
        for reference in newProject.references.values {
            let dataProvider = ProjectSourceDataProvider(reference.source)
            let bundle = reference.bundle()
            await bundleRepository.registerBundle(bundle, withProvider: dataProvider)
        }

        project = newProject

        // Plugins
        logger.debug("[open] updating plugins")
        for plugin in plugins {
            do {
                try await plugin.load(newProject, in: self)
            } catch {
                logger.error("[open] failed to update plugin '\(plugin.pluginId)': \(error)")
                throw error
            }
        }

        // Load Search Index
        logger.debug("[open] loading search index")
        let search = try loadSearchIndex(
            config: config,
            projectId: newProject.identifier,
            fileManager: fileManager
        )

        self.search = search
    }

    func addBundle(
        _ bundle: DocumentationBundle,
        with provider: BundleRepositoryProvider
    ) async throws {
        logger.info("[addBundle] adding \(bundle)")
        guard await bundleRepository.bundle(with: bundle.identifier) == nil else {
            logger.error(
                "cannot add duplicate bundle '\(bundle)'. There exists a bundle with '\(bundle.identifier)'"
            )
            throw WorkspaceError.duplicateBundle(id: bundle.identifier)
        }
        
        await bundleRepository.registerBundle(bundle, withProvider: provider)

        do {
            for plugin in plugins {
                do {
                    try await plugin.didAddBundle(with: bundle.identifier, in: self)
                } catch {
                    logger.error("[didAddBundle] failed for plugin '\(plugin.pluginId)': \(error)")
                    throw error
                }
            }
        } catch {
            logger.error("[addBundle] failed to add bundle to workspace \(bundle)")
            await bundleRepository.unregisterBundle(with: bundle.identifier)
        }
    }
}

extension Workspace {
    /// An error when requesting information from a workspace.
    public enum WorkspaceError: Error {
        /// A bundle with the provided ID wasn't found in the workspace.
        case duplicateBundle(id: BundleIdentifier)
        
        /// A bundle with the provided ID wasn't found in the workspace.
        case unknownBundle(id: BundleIdentifier)
        
        /// A data provider with the provided ID wasn't found in the workspace.
        case unknownProvider(id: String)
        
        /// A plain-text description of the error.
        public var errorDescription: String {
            switch self {
            case .duplicateBundle(let id):
                return "The bundle couldn't be added, because another bundle with id '\(id)' already exists in the workspace."
            case .unknownBundle(let id):
                return "The requested data could not be located because a containing bundle with id '\(id)' could not be found in the workspace."
            case .unknownProvider(let id):
                return "The requested data could not be located because a containing data provider with id '\(id)' could not be found in the workspace."
            }
        }
    }
    
}

private func loadSearchIndex(
    config: Workspace.Configuration,
    projectId: String,
    fileManager: FileManager
) throws -> SearchIndex {
    guard !config.inMemory else {
        return try SearchIndex()
    }

    let searchIndexUrl = URL
        .cachesDirectory
        .appending(components: projectId, "search")

    if !fileManager.fileExists(atPath: searchIndexUrl.path()) {
        try fileManager.createDirectory(at: searchIndexUrl, withIntermediateDirectories: true)
    }

    return try SearchIndex.openSearchIndex(at: searchIndexUrl, createIfNeeded: true)
}

// MARK: Configuration

extension Workspace {
    struct Configuration {
        var inMemory: Bool = false
    }
}

// MARK: DocumentationContext

extension Workspace: DocumentationContext {
    func bundle(with identifier: BundleIdentifier) async -> DocumentationBundle? {
        await bundleRepository.bundle(with: identifier)
    }

    func contentsOfUrl(_ url: URL) async throws -> Data {
        try await bundleRepository.contentsOfUrl(url)
    }
    
    func contentsOfUrl(_ url: DocumentationURI) async throws -> Data {
        try await bundleRepository.contentsOfUrl(url)
    }
}
