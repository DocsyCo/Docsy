//
//  DocumentationBundle 2.swift
//  Docsy
//
//  Created by Noah Kamara on 20.11.24.
//

import Foundation

struct DocumentationBundle: Identifiable, CustomStringConvertible, Sendable {
    var description: String { "Documenatation(identifier: '\(identifier)', displayName: '\(displayName)'" }
    var id: String { identifier }

    /// Information about this documentation bundle that's unrelated to its documentation content.
    let metadata: Metadata

    /// The bundle's human-readable display name.
    var displayName: String {
        metadata.displayName
    }

    /// The documentation bundle identifier.
    ///
    /// An identifier string that specifies the app type of the bundle.
    /// The string should be in reverse DNS format using only the Roman alphabet in
    /// upper and lower case (A–Z, a–z), the dot (“.”), and the hyphen (“-”).
    var identifier: BundleIdentifier {
        metadata.identifier
    }

    /// The documentation bundle's version.
    ///
    /// > It's not safe to make computations based on assumptions about the format of bundle's version. The version can be in any format.
//    public var version: String? {
//        metadata.version
//    }

    /// Symbol Graph JSON files for the modules documented by this bundle.
//    public let symbolGraphURLs: [URL]
//
//    /// DocC Markup files of the bundle.
//    public let documentURLs: [URL]
//
//    /// Miscellaneous resources of the bundle.
//    public let resourceImageURLs: [URL]
//
//    /// Miscellaneous resources of the bundle.
//    public let imageURLs: [URL]
//
//    /// Miscellaneous resources of the bundle.
//    public let videoURLs: [URL]
//
//    /// A custom HTML file to use as the header for rendered output.
//    public let customHeader: URL?
//
//    /// A custom HTML file to use as the footer for rendered output.
//    public let customFooter: URL?

    /// A custom JSON settings file used to theme renderer output.
    let themeSettingsUrl: URL?

    /// A URL prefix to be appended to the relative presentation URL.
    let baseURL: URL

    /// Creates a documentation bundle.
    ///
    /// - Parameters:
    ///   - info: Information about the bundle.
    ///   - baseURL: A URL prefix to be appended to the relative presentation URL.
    ///   - indexURL: The url to the index
    ///   - symbolGraphURLs: Symbol Graph JSON files for the modules documented by the bundle.
    ///   - markupURLs: DocC Markup files of the bundle.
    ///   - miscResourceURLs: Miscellaneous resources of the bundle.
    ///   - customHeader: A custom HTML file to use as the header for rendered output.
    ///   - customFooter: A custom HTML file to use as the footer for rendered output.
    ///   - themeSettings: A custom JSON settings file used to theme renderer output.
    init(
        info: Metadata,
        baseURL: URL = URL(string: "/")!,
//        indexURL: URL,
//        symbolGraphURLs: [URL],
//        documentURLs: [URL],
//        miscResourceURLs: [URL],
//        customHeader: URL? = nil,
//        customFooter: URL? = nil,
        themeSettingsUrl: URL? = nil
    ) {
        self.metadata = info
        self.baseURL = baseURL
//        self.indexURL = indexURL
//        self.symbolGraphURLs = symbolGraphURLs
//        self.documentURLs = documentURLs
//        self.miscResourceURLs = miscResourceURLs
//        self.customHeader = customHeader
//        self.customFooter = customFooter
//        self.themeSettings = themeSettings

//        let documentationRootReference = TopicReference(
//            bundleIdentifier: info.identifier,
//            path: "/documentation",
//            sourceLanguage: .swift
//        )
//        let tutorialsRootReference = TopicReference(
//            bundleIdentifier: info.identifier,
//            path: "/tutorials",
//            sourceLanguage: .swift
//        )
        
        self.themeSettingsUrl = themeSettingsUrl
//        self.rootReference = TopicReference(bundleIdentifier: info.identifier, path: "", sourceLanguages: [])
//        self.documentationRootReference = documentationRootReference
//        self.tutorialsRootReference = tutorialsRootReference
//        self.technologyTutorialsRootReference = tutorialsRootReference.appendingPath(urlReadablePath(info.displayName))
//        self.articlesDocumentationRootReference = documentationRootReference.appendingPath(urlReadablePath(info.displayName))
        
    }

//    public let rootReference: TopicReference
//
//    /// Default path to resolve symbol links.
//    public let documentationRootReference: TopicReference
//
//    /// Default path to resolve technology links.
//    public let tutorialsRootReference: TopicReference
//
//    /// Default path to resolve tutorials.
//    public let technologyTutorialsRootReference: TopicReference
//
//    /// Default path to resolve articles.
//    public let articlesDocumentationRootReference: TopicReference
}


extension DocumentationBundle {
    struct Metadata: Codable, Equatable, Sendable {
        /// The display name of the bundle.
        public var displayName: String

        /// The unique identifier of the bundle.
        public var identifier: String

//        /// The version of the bundle.
//        public var version: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "bundleDisplayName"
            case identifier = "bundleIdentifier"
        }

        public init(displayName: String, identifier: String) {
            self.displayName = displayName
            self.identifier = identifier
        }
    }
}
