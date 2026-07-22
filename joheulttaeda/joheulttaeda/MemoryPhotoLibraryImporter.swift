import Combine
import Foundation
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

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

struct MemoryPhotoLibraryImportBatch: Identifiable, Sendable {
    let id = UUID()
    let photoIDs: [UUID]
}

struct MemoryPhotoImportPreview: Identifiable {
    let id: String
    let photoID: UUID?
    let image: UIImage?
}

@MainActor
final class MemoryPhotoImportPresentationStore: ObservableObject {
    static let shared = MemoryPhotoImportPresentationStore()

    private static let pendingPhotoIDsDefaultsKey =
        "memory.photoLibrary.pendingPresentationPhotoIDs"
    private static let presentationIsVisibleDefaultsKey =
        "memory.photoLibrary.presentationIsVisible"

    @Published private(set) var batch: MemoryPhotoLibraryImportBatch?
    @Published private(set) var isVisible: Bool
    @Published private(set) var previews: [MemoryPhotoImportPreview] = []

    private init() {
        let defaults = UserDefaults.standard
        let photoIDs = defaults.stringArray(
            forKey: Self.pendingPhotoIDsDefaultsKey
        )?
        .compactMap(UUID.init(uuidString:)) ?? []

        if photoIDs.isEmpty {
            batch = nil
            isVisible = false
        } else {
            batch = MemoryPhotoLibraryImportBatch(photoIDs: photoIDs)
            isVisible = defaults.bool(
                forKey: Self.presentationIsVisibleDefaultsKey
            )
        }
    }

    func append(photoIDs: [UUID]) {
        guard !photoIDs.isEmpty else { return }

        let existingPhotoIDs = batch?.photoIDs ?? []
        var seenPhotoIDs = Set<UUID>()
        let mergedPhotoIDs = (existingPhotoIDs + photoIDs).filter {
            seenPhotoIDs.insert($0).inserted
        }

        batch = MemoryPhotoLibraryImportBatch(photoIDs: mergedPhotoIDs)
        isVisible = true
        persist(photoIDs: mergedPhotoIDs, isVisible: true)
    }

    func beginPreviews(assetIdentifiers: [String]) {
        guard !assetIdentifiers.isEmpty else { return }

        var existingIdentifiers = Set(previews.map(\.id))
        for assetIdentifier in assetIdentifiers
            where existingIdentifiers.insert(assetIdentifier).inserted {
            previews.append(
                MemoryPhotoImportPreview(
                    id: assetIdentifier,
                    photoID: nil,
                    image: nil
                )
            )
        }

        if batch == nil {
            batch = MemoryPhotoLibraryImportBatch(photoIDs: [])
        }
        isVisible = true
        persist(photoIDs: batch?.photoIDs ?? [], isVisible: true)
    }

    func updatePreviewImage(
        _ image: UIImage,
        assetIdentifier: String
    ) {
        guard let index = previews.firstIndex(where: { $0.id == assetIdentifier }) else {
            return
        }

        previews[index] = MemoryPhotoImportPreview(
            id: assetIdentifier,
            photoID: previews[index].photoID,
            image: image
        )
    }

    func completePreview(
        assetIdentifier: String,
        photoID: UUID
    ) {
        // The user may have already left the completion screen while the
        // original file was being copied. Do not present it again in that case.
        guard let index = previews.firstIndex(where: { $0.id == assetIdentifier }) else {
            return
        }

        // Keep the PhotoKit preview alive while the completion screen is open.
        // This lets its high-quality request replace the fast first frame even
        // after the original file has already been stored.
        previews[index] = MemoryPhotoImportPreview(
            id: assetIdentifier,
            photoID: photoID,
            image: previews[index].image
        )
        append(photoIDs: [photoID])
    }

    func cancelPreview(assetIdentifier: String) {
        previews.removeAll { $0.id == assetIdentifier }

        if previews.isEmpty, batch?.photoIDs.isEmpty != false {
            clear()
        }
    }

    func clear() {
        isVisible = false
        batch = nil
        previews = []
        UserDefaults.standard.removeObject(
            forKey: Self.pendingPhotoIDsDefaultsKey
        )
        UserDefaults.standard.removeObject(
            forKey: Self.presentationIsVisibleDefaultsKey
        )
    }

    private func persist(photoIDs: [UUID], isVisible: Bool) {
        UserDefaults.standard.set(
            photoIDs.map(\.uuidString),
            forKey: Self.pendingPhotoIDsDefaultsKey
        )
        UserDefaults.standard.set(
            isVisible,
            forKey: Self.presentationIsVisibleDefaultsKey
        )
    }
}

@MainActor
enum MemoryPhotoLibraryImporter {
    static let automaticImportEnabledDefaultsKey =
        "memory.photoLibrary.automaticImportEnabled"

    private static let automaticImportSetupCompletedDefaultsKey =
        "memory.photoLibrary.automaticImportSetupCompleted"

    private static let automaticImportWasDisabledByUserDefaultsKey =
        "memory.photoLibrary.automaticImportWasDisabledByUser"

    private static let automaticImportStartDateDefaultsKey =
        "memory.photoLibrary.automaticImportStartDate"

    private static let lastSyncDateDefaultsKey =
        "memory.photoLibrary.lastSyncDate"

    private static let photoKitIndexingOverlap: TimeInterval = 5 * 60
    private static let foregroundRetryDelaysNanoseconds: [UInt64] = [
        50_000_000,
        100_000_000,
        200_000_000,
        400_000_000,
        800_000_000,
        1_600_000_000
    ]

    private static var importIsRunning = false
    private static var anotherImportPassIsNeeded = false
    private static var foregroundImportGeneration = 0

    static var automaticImportIsEnabled: Bool {
        UserDefaults.standard.bool(forKey: automaticImportEnabledDefaultsKey)
    }

    static var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static var automaticImportWasDisabledByUser: Bool {
        UserDefaults.standard.bool(
            forKey: automaticImportWasDisabledByUserDefaultsKey
        )
    }

    /// Enables the camera-library workflow once for existing installations.
    /// A value explicitly chosen in Memory settings is always preserved.
    static func prepareAutomaticImportIfNeeded() async -> PHAuthorizationStatus {
        let defaults = UserDefaults.standard

        if automaticImportWasDisabledByUser {
            return authorizationStatus
        }

        let status: PHAuthorizationStatus
        if authorizationStatus == .notDetermined {
            defaults.set(true, forKey: automaticImportSetupCompletedDefaultsKey)
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            defaults.set(true, forKey: automaticImportSetupCompletedDefaultsKey)
            status = authorizationStatus
        }

        guard status == .authorized else {
            if status != .notDetermined {
                defaults.set(false, forKey: automaticImportEnabledDefaultsKey)
            }
            return status
        }

        if !automaticImportIsEnabled {
            establishNewImportBaseline()
        }
        return status
    }

    static func setAutomaticImportEnabled(
        _ enabled: Bool
    ) async -> PHAuthorizationStatus {
        UserDefaults.standard.set(
            true,
            forKey: automaticImportSetupCompletedDefaultsKey
        )
        UserDefaults.standard.set(
            !enabled,
            forKey: automaticImportWasDisabledByUserDefaultsKey
        )

        guard enabled else {
            UserDefaults.standard.set(false, forKey: automaticImportEnabledDefaultsKey)
            UserDefaults.standard.removeObject(
                forKey: automaticImportStartDateDefaultsKey
            )
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
        establishNewImportBaseline()
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
        defer { importIsRunning = false }

        repeat {
            anotherImportPassIsNeeded = false
            await performImportPass(modelContext: modelContext)
        } while anotherImportPassIsNeeded
    }

    /// PhotoKit can publish a camera asset shortly after the app becomes active.
    /// Check immediately, then use a short retry burst so the completion UI does
    /// not depend solely on a delayed library-change callback.
    static func importNewPhotosAfterForegroundActivation(
        modelContext: ModelContext
    ) async {
        foregroundImportGeneration &+= 1
        let generation = foregroundImportGeneration

        await importNewPhotos(modelContext: modelContext)

        for delay in foregroundRetryDelaysNanoseconds {
            guard
                !Task.isCancelled,
                generation == foregroundImportGeneration
            else {
                return
            }

            try? await Task.sleep(nanoseconds: delay)

            guard
                !Task.isCancelled,
                generation == foregroundImportGeneration
            else {
                return
            }

            await importNewPhotos(modelContext: modelContext)
        }
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
        let overlapStartDate = lastSyncDate.addingTimeInterval(
            -photoKitIndexingOverlap
        )
        let queryStartDate = max(
            automaticImportStartDate ?? lastSyncDate,
            overlapStartDate
        )
        let assets = newImageAssets(createdAfter: queryStartDate)
        var importedAssetIdentifiers = storedAssetIdentifiers(modelContext: modelContext)
        var everyAssetSucceeded = true

        let assetsToImport = assets.filter {
            !importedAssetIdentifiers.contains($0.localIdentifier)
        }

        if !assetsToImport.isEmpty {
            let presentationStore = MemoryPhotoImportPresentationStore.shared
            let frontAsset = assetsToImport[assetsToImport.count - 1]
            let frontAssetIdentifier = frontAsset.localIdentifier
            let frontImage: UIImage?
            if let fastImage = await fastPreviewImage(for: frontAsset) {
                frontImage = fastImage
            } else {
                frontImage = await highQualityPreviewImage(for: frontAsset)
            }

            // The newest photo is the front card. Resolve at least one image
            // before presenting so Gotcha never opens with an empty photo card.
            // Camera assets are local, so the fast request normally completes
            // within the app-switch transition.
            presentationStore.beginPreviews(
                assetIdentifiers: assetsToImport.map(\.localIdentifier)
            )
            if let frontImage {
                presentationStore.updatePreviewImage(
                    frontImage,
                    assetIdentifier: frontAssetIdentifier
                )
            }

            // Upgrade the visible card without delaying Gotcha. Other cards use
            // the same fast-first strategy so tapping never reveals a blank card.
            for asset in assetsToImport {
                let assetIdentifier = asset.localIdentifier
                Task { @MainActor in
                    if assetIdentifier != frontAssetIdentifier,
                       let image = await fastPreviewImage(for: asset) {
                        presentationStore.updatePreviewImage(
                            image,
                            assetIdentifier: assetIdentifier
                        )
                    }

                    guard let image = await highQualityPreviewImage(for: asset) else {
                        return
                    }
                    presentationStore.updatePreviewImage(
                        image,
                        assetIdentifier: assetIdentifier
                    )
                }
            }

            // Let SwiftUI draw the completion screen before original-file
            // copying and thumbnail generation begin on the main actor.
            await Task.yield()
        }

        for asset in assetsToImport {
            guard !Task.isCancelled else {
                everyAssetSucceeded = false
                break
            }

            let assetIdentifier = asset.localIdentifier
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
                MemoryPhotoImportPresentationStore.shared.completePreview(
                    assetIdentifier: assetIdentifier,
                    photoID: recorded.id
                )
            } catch {
                everyAssetSucceeded = false
                MemoryPhotoImportPresentationStore.shared.cancelPreview(
                    assetIdentifier: assetIdentifier
                )
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

    private static func highQualityPreviewImage(
        for asset: PHAsset
    ) async -> UIImage? {
        await previewImage(
            for: asset,
            maxDimension: 1_600,
            deliveryMode: .highQualityFormat,
            resizeMode: .exact,
            networkAccessAllowed: true
        )
    }

    private static func fastPreviewImage(
        for asset: PHAsset
    ) async -> UIImage? {
        await previewImage(
            for: asset,
            maxDimension: 1_280,
            deliveryMode: .fastFormat,
            resizeMode: .fast,
            networkAccessAllowed: false
        )
    }

    private static func previewImage(
        for asset: PHAsset,
        maxDimension: CGFloat,
        deliveryMode: PHImageRequestOptionsDeliveryMode,
        resizeMode: PHImageRequestOptionsResizeMode,
        networkAccessAllowed: Bool
    ) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = resizeMode
        options.version = .current
        options.isNetworkAccessAllowed = networkAccessAllowed

        let longestPixelDimension = max(asset.pixelWidth, asset.pixelHeight)
        let dimensionScale = longestPixelDimension > 0
            ? min(1, maxDimension / CGFloat(longestPixelDimension))
            : 1
        let targetSize = CGSize(
            width: max(1, CGFloat(asset.pixelWidth) * dimensionScale),
            height: max(1, CGFloat(asset.pixelHeight) * dimensionScale)
        )

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
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

    private static var automaticImportStartDate: Date? {
        guard UserDefaults.standard.object(
            forKey: automaticImportStartDateDefaultsKey
        ) != nil else {
            return nil
        }

        return Date(
            timeIntervalSince1970: UserDefaults.standard.double(
                forKey: automaticImportStartDateDefaultsKey
            )
        )
    }

    private static func establishNewImportBaseline() {
        let baseline = Date.now
        UserDefaults.standard.set(true, forKey: automaticImportEnabledDefaultsKey)
        UserDefaults.standard.set(
            baseline.timeIntervalSince1970,
            forKey: automaticImportStartDateDefaultsKey
        )
        setLastSyncDate(baseline)
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
