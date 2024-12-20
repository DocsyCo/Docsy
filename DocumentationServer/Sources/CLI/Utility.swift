//
//  File.swift
//  DocumentationServer
//
//  Created by Noah Kamara on 20.12.24.
//

import Foundation
import DocumentationKit

struct TimedOutError: Error, Equatable {}


public func withTimeout<R: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> R
) async throws -> R {
    return try await withThrowingTaskGroup(of: R.self) { group in
        let deadline = Date(timeIntervalSinceNow: seconds)
        
        // Start actual work
        group.addTask {
            return try await operation()
        }
        
        // Start timeout child task
        group.addTask {
            let interval = deadline.timeIntervalSinceNow
            if interval > 0 {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            throw TimedOutError()
        }
        
        // Wait for the first task to complete
        let result = try await group.next()
        
        // Cancel any remaining tasks
        group.cancelAll()
        
        return try result ?? { throw TimedOutError() }()
    }
}


extension DocumentationRepository {
    func addBundle(
        at path: String?,
        displayName: consuming String?,
        identifier: consuming String?,
        tag: String
    ) async throws -> BundleDetail {
        
        if
            let rootURL = path.map({ URL(filePath: $0) }),
            (displayName == nil || identifier == nil)
        {
            let provider = try LocalFileSystemDataProvider(
                rootURL: rootURL,
                allowArbitraryCatalogDirectories: true
            )
            
            guard let bundle = try provider.bundles().first else {
                throw ConsoleError("did not find bundle at \(rootURL)")
            }
            
            if displayName == nil {
                displayName = bundle.displayName
            }
            if identifier == nil {
                identifier = bundle.identifier
            }
        }
        
        
        guard let identifier, let displayName else {
            throw ConsoleError("Provider at least --archive , or --displayName AND --identifier")
        }
        
        let bundle = try await addBundle(displayName: displayName, identifier: identifier)
        
        print("warn: not uploading bundle data")
        
        return bundle
    }
}
