//
//  SourceBrowser.swift
//  DocSee
//
//  Created by Noah Kamara on 09.11.24.
//

import SwiftUI

//
//
//struct BundlePreview: View {
//    let bundle: Project.Bundle
//    
//    var body: some View {
//        HStack(alignment: .top) {
//            switch bundle.source.kind {
//            case .localFS: PageTypeIcon(.symbol("folder"))
//            case .index: PageTypeIcon(.symbol("magnifyingglass"))
//            case .http: PageTypeIcon(.symbol("network"))
//            }
//            
//            VStack(alignment: .leading) {
//                Text(bundle.metadata.displayName)
//                Text(bundle.metadata.identifier)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//        }
//    }
//}

//#Preview {
//    let metadata = DocumentationBundle.Metadata(
//        displayName: "Retry",
//        identifier: "com.example.retry"
//    )
//    
//    let httpSource = DocumentationSource.HTTP(
//        baseURL: URL(string: "https://swiftpackageindex.com/ph1ps/swift-concurrency-retry/0.0.1")!,
//        indexPath: "index",
//        metadata: metadata
//    )
//    
//    BundlePreview(bundle: .init(source: .http(httpSource), metadata: metadata))
//}

import DocumentationKit

@Observable
class BundleImporter {
    let repository: DocumentationRepository
    var bundleIdentifier: String = ""
    var bundleDisplayName: String = ""
    
    init(repository: DocumentationRepository) {
        self.repository = repository
    }
    
    enum Source: CaseIterable, Hashable {
        case filesystem
        case url
        
        var displayName: String {
            switch self {
            case .filesystem: "Files"
            case .url: "URL"
            }
        }
    }
    
    var source: Source? = nil
    
    let filesystem = FilesystemImporter()
    
    struct ImportError: Error {
        let message: String
        
        init(_ message: String) {
            self.message = message
        }
        
        static let invalidSource = ImportError("Invalid source")
    }
    
    func `import`() async throws {
        let (sourceURL, bundle, _) = switch source {
        case .filesystem: try filesystem.sourceProvider()
        case .url: fatalError() //filesystem.provider()
        case nil: throw ImportError.invalidSource
        }
        
        let bundleId = try await repository.addBundle(
            displayName: bundle.displayName,
            identifier: bundle.identifier
        ).id
        
        _ = try await repository.addRevision(
            "latest",
            source: sourceURL,
            toBundle: bundleId
        )
    }
    
    @Observable
    class FilesystemImporter {
        let fileManager: FileManager = .default
        var fileURL: URL? = nil
        
        var isValid: Bool {
            access(keyPath: \.fileURL)
            return fileURL != nil
        }
        
        func sourceProvider() throws -> (
            URL,
            DocumentationBundle.Metadata,
            BundleRepositoryProvider
        ) {
            guard let fileURL else {
                throw ImportError.invalidSource
            }
            
            guard fileURL.startAccessingSecurityScopedResource() else {
                throw ImportError("Could not access file at '\(fileURL.path())'")
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            let provider = try LocalFileSystemDataProvider(
                rootURL: fileURL,
                allowArbitraryCatalogDirectories: true,
                fileManager: fileManager
            )
            
            return (fileURL, try provider.bundles().first!.metadata, provider)
        }
    }
    
    var isValid: Bool {
        access(keyPath: \.source)
        access(keyPath: \.filesystem)
        return switch source {
        case .filesystem: filesystem.isValid
//        case .httpUrl: httpUrl.isValid
        default: false
            //        case nil: false
        }
    }
}

struct BundleImportView: View {
    @Bindable
    var importer: BundleImporter
    
    init(importer: BundleImporter) {
        self.importer = importer
    }
    
    init(repository: DocumentationRepository) {
        self.init(importer: .init(repository: repository))
    }
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Source") {
                    Picker("", selection: $importer.source) {
                        Text("Select a source")
                            .tag(BundleImporter.Source?.none)
                            .disabled(true)
                        
                        ForEach(BundleImporter.Source.allCases, id:\.self) { source in
                            Text(source.displayName)
                                .tag(source)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
            
            if let source = importer.source {
                switch source {
                case .filesystem:
                    FilesImportView(config: importer.filesystem)
                    
                case .url:
                    Text("URL")
                }
                
                Section {
                    TextField("Bundle Identifier", text: $importer.bundleIdentifier)
                    TextField("Display Name", text: $importer.bundleIdentifier)
//                    LabeledContent("Display Name") {
//                        <#code#>
//                    }
                } header: {
                    HStack {
                        Text("Metadata")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                
                Section {
                    LabeledContent("Index Directory") {
                        
                    }
                } header: {
                    HStack {
                        Text("Navigator Index")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            } else {
                ContentUnavailableView("Select a source to get started", systemImage: "exclamationmark.octagon")
                    .frame(maxWidth: .infinity, alignment: .center)

            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                AsyncButton("Import") {
                    try await importer.import()
                }
                .disabled(!importer.isValid)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(10)
            .background(.background)
        }
    }
    
    struct FilesImportView: View {
        let config: BundleImporter.FilesystemImporter
        
        @State
        private var isPresentingFileImporter: Bool = false

        var body: some View {
            Section("Filesystem") {
                LabeledContent("Path") {
                    Button(action: { isPresentingFileImporter = true }) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(config.fileURL?.path() ?? "Select a documentation archive")
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: "arrowshape.right.circle.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    .lineLimit(2)
                }
                .fileImporter(
                    isPresented: $isPresentingFileImporter,
                    allowedContentTypes: [.doccarchive]
                ) { result in
                    switch result {
                    case .success(let fileURL):
                        config.fileURL = fileURL
                    case .failure(let failure):
                        print("failed", failure)
                    }
                }
            }
        }
    }
}

enum ImporterStatus {
    case success
    case warning(_ reason: String)
    case error(_ reason: String)
}


import UniformTypeIdentifiers

extension UTType {
    static var doccarchive: UTType {
        .init(importedAs: "com.apple.documentation.archive", conformingTo: .directory)
    }
}


#Preview {
    @Previewable var repository = InMemoryDocumentationRepository()
    
    let resource = try! CachedResource()
    
    let importer: BundleImporter = try! {
        let importer = BundleImporter(repository: repository)
        importer.source = .filesystem
        let metadata = DocumentationBundle.Metadata(
            displayName: "Example Documentation",
            identifier: "com.example.documentation"
        )
        
        try resource.put(metadata, at: "metadata.json")
        importer.filesystem.fileURL = resource.url
        return importer
    }()
    
    BundleImportView(importer: importer)
}
//struct BundleBrowserView: View {
////    let didSubmit: (Project.Bundle) async throws -> Void
////    
////    @State
////    private var bundle: Project.Bundle? = nil
////    
////    @State
////    var sourceKind: DocumentationSource.Kind = .http
//    
//    @Environment(\.dismiss)
//    private var dismiss
//    
//    var body: some View {
//        Form {
//            Picker("Source", selection: $sourceKind) {
//                Text("Select Source")
//                    .tag(DocumentationSource.Kind?.none)
//                    .disabled(true)
//                Text("HTTP").tag(DocumentationSource.Kind.http)
//                Text("DocSee Index").tag(DocumentationSource.Kind.index)
//                Text("Local FileSystem").tag(DocumentationSource.Kind.localFS)
//            }
//            
//            if let bundle {
//                Section {
//                    BundlePreview(bundle: bundle)
//                }
//                
//                Section("Validation") {
//                    LabeledContent("Documentation Index") {
//                        switch indexValidation {
//                        case .none: ProgressView()
//                        case .success:
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundStyle(.green)
//                        case .failed(let reason):
//                            Text(reason ?? "invalid")
//                                .foregroundStyle(.red)
//                        }
//                    }
//                }
//                
//                
//                AsyncButton("Add '\(bundle.metadata.displayName)'") {
//                    do {
//                        guard await validateBundle(bundle) == .success else {
//                            return
//                        }
//                        try await didSubmit(bundle)
//                        
//                        dismiss()
//                    } catch {
//                        print("error", error)
//                        throw error
//                    }
//                }
//            } else {
//                switch sourceKind {
//                case .localFS:
//                    Text("Not Implemented")
//                case .index:
//                    Text("Not Implemented")
//                case .http:
//                    HTTPSourceCreateView { bundle in
//                        validate(bundle)
//                    }
//                }
//            }
//        }
//        .presentationDetents(bundle == nil ? [.medium, .large] : [.medium])
//    }
//    
//    func validate(_ bundle: Project.Bundle) {
//        self.bundle = bundle
//        
//        self.validationTask?.cancel()
//        self.validationTask = Task {
//            let result = await self.validateBundle(bundle)
//            self.indexValidation = result
//        }
//    }
//    
//    @State
//    private var indexValidation: ValidatationResult? = nil
//    @State
//    private var validationTask: Task<Void, Never>? = nil
//    
//    func validateBundle(_ bundle: Project.Bundle) async -> ValidatationResult? {
//        do {
//            let provider = try PersistableDataProvider(source: bundle.source)
//            
//            guard let bundle = try await provider.bundles().first else {
//                return .failed("internal: failed to discover bundle")
//            }
//            
//            do {
//                let indexData = try await provider.contentsOfURL(bundle.indexURL)
//                do {
//                    _ = try JSONDecoder().decode(DocumentationIndex.self, from: indexData)
//                } catch {
//                    return .failed("invalid data")
//                }
//            } catch {
//                return .failed("could not load index")
//            }
//        } catch {
//            return .failed("internal: failed to create provider")
//        }
//        
//        return .success
//    }
//}
//
//#Preview {
//    BundleBrowserView(didSubmit: { bundle in
//        print(bundle)
//    })
//}

//extension DocumentationRepository {
//    func addBundle(
//        at path: String?,
//        displayName: consuming String?,
//        identifier: consuming String?,
//        source: URL? = nil,
//        tag: String
//    ) async throws -> BundleDetail {
//        
//        if
//            let rootURL = path.map({ URL(filePath: $0) }),
//            (displayName == nil || identifier == nil)
//        {
//            let provider = try LocalFileSystemDataProvider(
//                rootURL: rootURL,
//                allowArbitraryCatalogDirectories: true
//            )
//            
//            guard let bundle = try provider.bundles().first else {
//                throw ConsoleError("did not find bundle at \(rootURL)")
//            }
//            
//            if displayName == nil {
//                displayName = bundle.displayName
//            }
//            if identifier == nil {
//                identifier = bundle.identifier
//            }
//        }
//        
//        
//        guard let identifier, let displayName else {
//            throw ConsoleError("Provide at least --archive , or --displayName AND --identifier")
//        }
//        
//        let bundleId = try await addBundle(displayName: displayName, identifier: identifier).id
//        
//        if let path {
//            _ = try await addRevision(tag, source: source ?? URL(filePath: path), toBundle: bundleId)
//        }
//        print("warn: not uploading bundle data")
//        
//        guard let bundle = try await self.bundle(bundleId) else {
//            throw ConsoleError("Failed to find bundle on server")
//        }
//        
//        return bundle
//    }
//}
