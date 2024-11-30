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
    static func docsy(_ category: String) -> Logger {
        Logger(subsystem: "com.noahkamara.docsy", category: category)
    }
}

public class Workspace {
    let logger: Logger = .docsy("workspace")

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
}
