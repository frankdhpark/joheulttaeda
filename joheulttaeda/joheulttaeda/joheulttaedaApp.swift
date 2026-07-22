//
//  joheulttaedaApp.swift
//  joheulttaeda
//
//  Created by donghun park on 7/20/26.
//

import SwiftUI
import SwiftData

@main
struct joheulttaedaApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [IdeaMediaItem.self, MemoryPhoto.self])
    }
}

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ContentView()
            .task {
                MemoryPhotoLibraryChangeMonitor.shared.startObserving {
                    await MemoryPhotoLibraryImporter.importNewPhotos(
                        modelContext: modelContext
                    )
                }
                await processPendingWork()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await processPendingWork()
                }
            }
    }

    private func processPendingWork() async {
        await MemoryPhotoLibraryImporter.importNewPhotos(
            modelContext: modelContext
        )
        await MemoryPhotoAutoClassifier.resumePendingClassifications(
            modelContext: modelContext
        )
        await IdeaImportCoordinator.shared.consumePendingImports(
            modelContext: modelContext
        )
    }
}
