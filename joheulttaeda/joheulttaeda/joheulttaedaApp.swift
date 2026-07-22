//
//  joheulttaedaApp.swift
//  joheulttaeda
//
//  Created by donghun park on 7/20/26.
//

import SwiftUI
import SwiftData
import Photos

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
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var photoLibraryAccessNeedsAttention = false
    @State private var hasPresentedPhotoLibraryAccessGuidance = false

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
            .alert(
                "사진 전체 접근이 필요합니다",
                isPresented: $photoLibraryAccessNeedsAttention
            ) {
                Button("설정 열기") {
                    guard let settingsURL = URL(
                        string: UIApplication.openSettingsURLString
                    ) else { return }
                    openURL(settingsURL)
                }
                Button("나중에", role: .cancel) {}
            } message: {
                Text(
                    "기본 카메라로 촬영한 새 사진을 자동으로 가져오려면 "
                        + "사진 접근을 ‘전체 접근’으로 허용해주세요."
                )
            }
    }

    private func processPendingWork() async {
        let authorizationStatus = await MemoryPhotoLibraryImporter
            .prepareAutomaticImportIfNeeded()

        if authorizationStatus != .authorized,
           authorizationStatus != .notDetermined,
           !MemoryPhotoLibraryImporter.automaticImportWasDisabledByUser,
           !hasPresentedPhotoLibraryAccessGuidance {
            hasPresentedPhotoLibraryAccessGuidance = true
            photoLibraryAccessNeedsAttention = true
        }

        await MemoryPhotoLibraryImporter.importNewPhotosAfterForegroundActivation(
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
