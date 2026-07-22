import Foundation
import Photos
import PhotosUI
import SwiftData
import SwiftUI

enum MemoryPhotoLibraryImportError: LocalizedError {
    case imageDataUnavailable

    var errorDescription: String? {
        switch self {
        case .imageDataUnavailable:
            "사진 보관함에서 이미지 데이터를 가져올 수 없습니다."
        }
    }
}

struct MemoryPhotoPickerImportResult: Sendable {
    let importedCount: Int
    let skippedCount: Int
    let failedCount: Int
}

@MainActor
enum MemoryPhotoLibraryImporter {
    static let automaticImportEnabledDefaultsKey =
        "memory.photoLibrary.automaticImportEnabled"

    private static let lastSyncDateDefaultsKey =
        "memory.photoLibrary.lastSyncDate"

    private static var importIsRunning = false
    private static var anotherImportPassIsNeeded = false

    static var automaticImportIsEnabled: Bool {
        UserDefaults.standard.bool(forKey: automaticImportEnabledDefaultsKey)
    }

    static var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func setAutomaticImportEnabled(
        _ enabled: Bool
    ) async -> PHAuthorizationStatus {
        guard enabled else {
            UserDefaults.standard.set(false, forKey: automaticImportEnabledDefaultsKey)
            UserDefaults.standard.removeObject(forKey: lastSyncDateDefaultsKey)
            return authorizationStatus
        }

        let status: PHAuthorizationStatus
        if authorizationStatus == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            status = authorizationStatus
        }

        guard status == .authorized else {
            UserDefaults.standard.set(false, forKey: automaticImportEnabledDefaultsKey)
            return status
        }

        // Enabling the feature establishes a new baseline, so existing library
        // photos and photos added while the feature was off aren't imported.
        UserDefaults.standard.set(true, forKey: automaticImportEnabledDefaultsKey)
        setLastSyncDate(.now)
        return status
    }

    static func importNewPhotos(
        modelContext: ModelContext
    ) async {
        guard automaticImportIsEnabled else { return }

        guard authorizationStatus == .authorized else {
            UserDefaults.standard.set(false, forKey: automaticImportEnabledDefaultsKey)
            return
        }

        if importIsRunning {
            anotherImportPassIsNeeded = true
            return
        }

        importIsRunning = true

        repeat {
            anotherImportPassIsNeeded = false
            await performImportPass(modelContext: modelContext)
        } while anotherImportPassIsNeeded

        importIsRunning = false
    }

    static func importSelectedPhotos(
        _ items: [PhotosPickerItem],
        modelContext: ModelContext
    ) async -> MemoryPhotoPickerImportResult {
        var importedCount = 0
        var skippedCount = 0
        var failedCount = 0
        var importedAssetIdentifiers = storedAssetIdentifiers(modelContext: modelContext)

        for item in items {
            guard !Task.isCancelled else { break }

            let assetIdentifier = item.itemIdentifier
            if let assetIdentifier,
               importedAssetIdentifiers.contains(assetIdentifier) {
                skippedCount += 1
                continue
            }

            do {
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    throw MemoryPhotoLibraryImportError.imageDataUnavailable
                }

                let capturedAt = assetIdentifier
                    .flatMap(assetCreationDate(localIdentifier:)) ?? .now
                let recorded = try MemoryPhotoRecorder.record(
                    photoData: imageData,
                    capturedAt: capturedAt,
                    sourceAssetLocalIdentifier: assetIdentifier,
                    importOrigin: .photosPicker,
                    modelContext: modelContext
                )

                if let assetIdentifier {
                    importedAssetIdentifiers.insert(assetIdentifier)
                }

                importedCount += 1
                await MemoryPhotoAutoClassifier.classify(
                    recorded: recorded,
                    modelContext: modelContext
                )
            } catch {
                failedCount += 1
            }
        }

        return MemoryPhotoPickerImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount,
            failedCount: failedCount
        )
    }

    private static func performImportPass(
        modelContext: ModelContext
    ) async {
        guard let lastSyncDate else {
            setLastSyncDate(.now)
            return
        }

        let syncStartedAt = Date.now
        let assets = newImageAssets(createdAfter: lastSyncDate)
        var importedAssetIdentifiers = storedAssetIdentifiers(modelContext: modelContext)
        var everyAssetSucceeded = true

        for asset in assets {
            guard !Task.isCancelled else {
                everyAssetSucceeded = false
                break
            }

            let assetIdentifier = asset.localIdentifier
            if importedAssetIdentifiers.contains(assetIdentifier) {
                continue
            }

            do {
                let imageData = try await imageData(for: asset)
                let recorded = try MemoryPhotoRecorder.record(
                    photoData: imageData,
                    capturedAt: asset.creationDate ?? .now,
                    sourceAssetLocalIdentifier: assetIdentifier,
                    importOrigin: .photoLibrary,
                    modelContext: modelContext
                )

                importedAssetIdentifiers.insert(assetIdentifier)
                await MemoryPhotoAutoClassifier.classify(
                    recorded: recorded,
                    modelContext: modelContext
                )
            } catch {
                everyAssetSucceeded = false
                #if DEBUG
                print(
                    "Memory PhotoKit import failed:",
                    assetIdentifier,
                    error.localizedDescription
                )
                #endif
            }
        }

        // A failed iCloud download is retried on the next activation. Assets
        // already copied are ignored through their PhotoKit local identifier.
        if everyAssetSucceeded {
            setLastSyncDate(syncStartedAt)
        }
    }

    private static func newImageAssets(
        createdAfter date: Date
    ) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate > %@",
            date as NSDate
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            guard
                asset.sourceType.contains(.typeUserLibrary),
                !asset.mediaSubtypes.contains(.photoScreenshot),
                !asset.isHidden
            else {
                return
            }

            assets.append(asset)
        }

        return assets
    }

    private static func imageData(
        for asset: PHAsset
    ) async throws -> Data {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.version = .current
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if info?[PHImageCancelledKey] as? Bool == true {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                guard let data else {
                    continuation.resume(
                        throwing: MemoryPhotoLibraryImportError.imageDataUnavailable
                    )
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    private static func storedAssetIdentifiers(
        modelContext: ModelContext
    ) -> Set<String> {
        let descriptor = FetchDescriptor<MemoryPhoto>()
        guard let photos = try? modelContext.fetch(descriptor) else {
            return []
        }

        return Set(photos.compactMap(\.sourceAssetLocalIdentifier))
    }

    private static func assetCreationDate(
        localIdentifier: String
    ) -> Date? {
        PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )
        .firstObject?
        .creationDate
    }

    private static var lastSyncDate: Date? {
        guard UserDefaults.standard.object(forKey: lastSyncDateDefaultsKey) != nil else {
            return nil
        }

        return Date(
            timeIntervalSince1970: UserDefaults.standard.double(
                forKey: lastSyncDateDefaultsKey
            )
        )
    }

    private static func setLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(
            date.timeIntervalSince1970,
            forKey: lastSyncDateDefaultsKey
        )
    }
}

@MainActor
final class MemoryPhotoLibraryChangeMonitor: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = MemoryPhotoLibraryChangeMonitor()

    private var changeHandler: (() async -> Void)?
    private var isRegistered = false

    func startObserving(
        onChange: @escaping () async -> Void
    ) {
        changeHandler = onChange

        guard !isRegistered else { return }
        PHPhotoLibrary.shared().register(self)
        isRegistered = true
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            await self?.changeHandler?()
        }
    }
}
