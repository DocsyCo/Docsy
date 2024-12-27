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
    
    var body: some Scene {
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
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {}
            }
            
#if os(macOS)
            CommandGroup(replacing: .windowList) {
                Button("Bundle Browser") {
                    openWindow(.bundleBrowser)
                }
                .keyboardShortcut("b", modifiers: .command)
            }
#endif
        }
    }
}
