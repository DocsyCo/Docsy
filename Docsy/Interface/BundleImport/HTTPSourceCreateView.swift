////
////  HTTPSourceCreateView.swift
////  DocSee
////
////  Created by Noah Kamara on 10.11.24.
////
//
//import SwiftUI
//import DocumentationKit
//
//// MARK: HTTPSourceCreate
//struct HTTPSourceCreateView: View {
//    private var baseURL: URL? {
//        URL(string: baseURLText.value)
//    }
//    
//    //MARK: URLs
//    @Bindable
//    var baseURLText = Validated.validURL(type: .deferred)
//    
//    @State
//    var indexPath: String = ""
//    
//    @State
//    var themePath: String = ""
//    
//    //MARK:  Metadata
//    @State
//    var bundleDisplayName: String = ""
//    
//    @Bindable
//    var bundleIdentifier = Validated.nonEmpty(type: .deferred)
//    
//    @State
//    private var validateInputs: Bool = false
//    
//    let didSubmit: (Project.Bundle) -> Void
//    
//    var body: some View {
//        Section("Bundle Metadata") {
//            LabeledContent("Identifier") {
//                TextField("", text: $bundleIdentifier.value)
//                    .validation(bundleIdentifier)
//                    .autocorrectionDisabled()
//#if os(iOS)
//                    .keyboardType(.URL)
//                    .textInputAutocapitalization(.never)
//#endif
//            }
//            
//            LabeledContent("Display Name") {
//                TextField(
//                    "",
//                    text: $bundleDisplayName,
//                    prompt: Text(bundleIdentifier.value)
//                )
//                .autocorrectionDisabled()
//            }
//            
//            AsyncButton("Autodetect Metadata") {
//                baseURLText.triggerValidatation()
//                bundleIdentifier.deferValidation()
//                
//                guard let baseURL else {
//                    throw UserError("Missing baseURL")
//                }
//                
//                let (data, _) = try await URLSession.shared.data(from: baseURL.appending(components: "metadata.json"))
//                
//                let metadata = try JSONDecoder().decode(DocumentationBundle.Metadata.self, from: data)
//                
//                self.bundleDisplayName = metadata.displayName
//                self.bundleIdentifier.value = metadata.identifier
//            }
//        }
//        
//        Section("Source") {
//            LabeledContent("URL") {
//                HStack(alignment: .firstTextBaseline) {
//                    TextField("", text: $baseURLText.value, prompt: Text("http://"))
//#if os(iOS)
//                        .keyboardType(.URL)
//#endif
//                        .validation(baseURLText)
//                        .labelsHidden()
//                }
//            }
//            
//            LabeledContent("Index") {
//                HStack(spacing: 2) {
//                    Text("/").foregroundStyle(.secondary)
//                    TextField("", text: $indexPath, prompt: Text("index/index.json"))
//                }
//                .labelsHidden()
//            }
//            
//            LabeledContent("Theme") {
//                HStack(spacing: 2) {
//                    Text("/").foregroundStyle(.secondary)
//                    TextField("", text: $themePath, prompt: Text("theme-settings.json"))
//                }
//                .labelsHidden()
//            }
//        }
//        .textFieldStyle(.plain)
//        .autocorrectionDisabled()
//        #if os(iOS)
//            .keyboardType(.URL)
//            .textInputAutocapitalization(.never)
//        #endif
//        
//        AsyncButton("Add '\(!bundleDisplayName.isEmpty ? bundleDisplayName : "Bundle")'") {
//            let preview = try createPreview()
//            didSubmit(preview)
//        }
//    }
//    
//    func createPreview() throws -> Project.Bundle {
//        bundleIdentifier.triggerValidatation()
//        baseURLText.triggerValidatation()
//        
//        guard !bundleIdentifier.isFailed, let baseURL else {
//            throw UserError("Form is not Valid")
//        }
//        
//        let metadata = DocumentationBundle.Metadata(
//            displayName: !bundleDisplayName.isEmpty ? bundleDisplayName : bundleIdentifier.value ,
//            identifier: bundleIdentifier.value
//        )
//        
//        let indexPath = !indexPath.isEmpty ? indexPath : "index/index.json"
//        
//        let config = DocumentationSource.HTTP(
//            baseURL: baseURL,
//            indexUrl: baseURL.appending(path: indexPath),
//            metadata: metadata
//        )
//        
//        let source = DocumentationSource.http(config)
//        
//        let bundle = Project.Bundle(source: source, metadata: metadata)
//        
//        return bundle
//    }
//}
//
//#Preview {
//    HTTPSourceCreateView(didSubmit: {
//        print("SUBMIT", $0)
//    })
//}
