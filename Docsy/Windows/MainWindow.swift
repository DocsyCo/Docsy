//
//  MainWindow.swift
//  DocSee
//
//  Created by Noah Kamara on 20.12.24.
//

import SwiftUI


struct MainWindow: Scene {
    @State
    var db: ApplicationDB? = nil
    
    let workspace: Workspace
    
    let repositories: DocumentationRepositories
    
    @Environment(\.openWindow)
    private var openWindow
    
    let appModel: AppModel
    
    var body: some Scene {
        @Bindable var appModel = appModel
        
        WindowGroup(id: WindowID.main.identifier) {
            if db != nil {
                MainView(workspace: workspace)
                    .environment(repositories)
            } else {
                ProgressView()
                    .task {
                        do {
                            let databaseURL = URL.temporaryDirectory.appending(component: "testdb")
                            print("DATABASEURL", databaseURL.path())
                            let db = try ApplicationDB()
                            
                            print(URL.temporaryDirectory.appending(component: "testdb"))
                            try? await PreviewDocumentationRepository.createPreviewBundles(db.documentation)
                            
                            self.db = db
                            repositories.addRepository(db.documentation, as: .local)
                        } catch {
                            print("failed to setup app db", error)
                        }
                    }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $appModel.showsBundleBrowser) {
            WorkspaceBundleBrowser(
                workspace: workspace,
                repositories: repositories
            )
        }
        #endif
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {}
            }
            
#if os(macOS)
            CommandGroup(replacing: .windowList) {
                OpenBundleBrowserButton()
                    .environment(appModel)
            }
#endif
        }
        .environment(appModel)
    }
}
