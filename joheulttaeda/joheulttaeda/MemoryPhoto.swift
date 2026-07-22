import Foundation
import ImageIO
import SwiftData
import UIKit
import UniformTypeIdentifiers

enum MemoryPhotoFolder: String, CaseIterable, Hashable, Identifiable, Sendable {
    case uncategorized = "uncategorized"
    case food
    case outing
    case walk
    case nap
    case costume
    case swimming
    case fashion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uncategorized:
            "미분류"
        case .food:
            "먹방"
        case .outing:
            "나들이"
        case .walk:
            "산책"
        case .nap:
            "낮잠"
        case .costume:
            "코스프레"
        case .swimming:
            "수영"
        case .fashion:
            "패션"
        }
    }
}

enum MemoryPhotoClassificationStatus: String, Codable {
    case pending
    case classified
    case unclassified
    case failed
}

enum MemoryPhotoImportOrigin: String, Codable, Sendable {
    case appCamera
    case photoLibrary
    case photosPicker
}

struct RecordedMemoryPhoto: Sendable {
    let id: UUID
    let thumbnailRelativePath: String
}

@Model
final class MemoryPhoto {
    @Attribute(.unique) var id: UUID
    var folderID: String = MemoryPhotoFolder.uncategorized.rawValue
    var originalRelativePath: String
    var thumbnailRelativePath: String
    var capturedAt: Date
    var classificationStatusRawValue: String = MemoryPhotoClassificationStatus.pending.rawValue
    var classificationIdentifier: String?
    var classificationConfidence: Double?
    var classificationModelVersion: String?
    var classifiedAt: Date?
    var sourceAssetLocalIdentifier: String?
    var importOriginRawValue: String = MemoryPhotoImportOrigin.appCamera.rawValue

    init(
        id: UUID = UUID(),
        folderID: String = MemoryPhotoFolder.uncategorized.rawValue,
        originalRelativePath: String,
        thumbnailRelativePath: String,
        capturedAt: Date = .now,
        sourceAssetLocalIdentifier: String? = nil,
        importOrigin: MemoryPhotoImportOrigin = .appCamera
    ) {
        self.id = id
        self.folderID = folderID
        self.originalRelativePath = originalRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.capturedAt = capturedAt
        self.sourceAssetLocalIdentifier = sourceAssetLocalIdentifier
        self.importOriginRawValue = importOrigin.rawValue
    }

    var thumbnailImage: UIImage? {
        MemoryPhotoStorage.image(forRelativePath: thumbnailRelativePath)
    }

    var originalImage: UIImage? {
        MemoryPhotoStorage.image(forRelativePath: originalRelativePath)
    }
}

enum MemoryPhotoStorageError: LocalizedError {
    case invalidImageData
    case thumbnailCreationFailed
    case invalidStoredPath
    case storedPhotoMissing
    case destinationAlreadyExists

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            "촬영된 사진 데이터를 읽을 수 없습니다."
        case .thumbnailCreationFailed:
            "Memory 사진의 미리보기를 만들 수 없습니다."
        case .invalidStoredPath:
            "Memory 사진의 저장 경로가 올바르지 않습니다."
        case .storedPhotoMissing:
            "이동할 Memory 사진 파일을 찾을 수 없습니다."
        case .destinationAlreadyExists:
            "이동할 Memory 폴더에 같은 사진이 이미 존재합니다."
        }
    }
}

enum MemoryPhotoStorage {
    struct StoredPhoto {
        let originalRelativePath: String
        let thumbnailRelativePath: String
    }

    struct StagedDeletion {
        fileprivate let originalDirectory: URL
        fileprivate let stagedDirectory: URL
    }

    private static let rootDirectoryName = "MemoryPhotos"
    private static let thumbnailMaxPixelSize: CGFloat = 1_280
    private static let thumbnailJPEGQuality: CGFloat = 0.92

    static func store(
        photoData: Data,
        folderID: String,
        id: UUID
    ) throws -> StoredPhoto {
        guard
            let source = CGImageSourceCreateWithData(photoData as CFData, nil)
        else {
            throw MemoryPhotoStorageError.invalidImageData
        }

        let directory = try itemDirectory(folderID: folderID, id: id)

        do {
            let originalExtension = preferredFilenameExtension(for: source)
            let originalURL = directory.appendingPathComponent("original.\(originalExtension)")
            try photoData.write(to: originalURL, options: .atomic)

            guard
                let thumbnailData = thumbnailData(
                    from: source,
                    maxDimension: thumbnailMaxPixelSize,
                    compressionQuality: thumbnailJPEGQuality
                )
            else {
                throw MemoryPhotoStorageError.thumbnailCreationFailed
            }

            let thumbnailURL = directory.appendingPathComponent("thumbnail.jpg")
            try thumbnailData.write(to: thumbnailURL, options: .atomic)

            for url in [originalURL, thumbnailURL] {
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            }

            return StoredPhoto(
                originalRelativePath: try relativePath(for: originalURL),
                thumbnailRelativePath: try relativePath(for: thumbnailURL)
            )
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    static func image(forRelativePath relativePath: String) -> UIImage? {
        guard let url = url(forRelativePath: relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func fileURL(forRelativePath relativePath: String) -> URL? {
        url(forRelativePath: relativePath)
    }

    static func moveStoredPhoto(
        id: UUID,
        originalRelativePath: String,
        thumbnailRelativePath: String,
        toFolderID folderID: String,
        fileManager: FileManager = .default
    ) throws -> StoredPhoto {
        guard
            let originalURL = url(
                forRelativePath: originalRelativePath,
                fileManager: fileManager
            ),
            let thumbnailURL = url(
                forRelativePath: thumbnailRelativePath,
                fileManager: fileManager
            )
        else {
            throw MemoryPhotoStorageError.invalidStoredPath
        }

        let sourceDirectory = originalURL
            .deletingLastPathComponent()
            .standardizedFileURL
        guard
            thumbnailURL.deletingLastPathComponent().standardizedFileURL == sourceDirectory,
            sourceDirectory.lastPathComponent == id.uuidString,
            fileManager.fileExists(atPath: originalURL.path),
            fileManager.fileExists(atPath: thumbnailURL.path)
        else {
            throw MemoryPhotoStorageError.storedPhotoMissing
        }

        let destinationFolder = try rootDirectory(fileManager: fileManager)
            .appendingPathComponent(safePathComponent(folderID), isDirectory: true)
        try fileManager.createDirectory(
            at: destinationFolder,
            withIntermediateDirectories: true
        )

        let destinationDirectory = destinationFolder
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .standardizedFileURL

        if sourceDirectory == destinationDirectory {
            return StoredPhoto(
                originalRelativePath: originalRelativePath,
                thumbnailRelativePath: thumbnailRelativePath
            )
        }

        guard !fileManager.fileExists(atPath: destinationDirectory.path) else {
            throw MemoryPhotoStorageError.destinationAlreadyExists
        }

        try fileManager.moveItem(at: sourceDirectory, to: destinationDirectory)

        do {
            let movedOriginalURL = destinationDirectory
                .appendingPathComponent(originalURL.lastPathComponent)
            let movedThumbnailURL = destinationDirectory
                .appendingPathComponent(thumbnailURL.lastPathComponent)

            guard
                fileManager.fileExists(atPath: movedOriginalURL.path),
                fileManager.fileExists(atPath: movedThumbnailURL.path)
            else {
                throw MemoryPhotoStorageError.storedPhotoMissing
            }

            return StoredPhoto(
                originalRelativePath: try relativePath(
                    for: movedOriginalURL,
                    fileManager: fileManager
                ),
                thumbnailRelativePath: try relativePath(
                    for: movedThumbnailURL,
                    fileManager: fileManager
                )
            )
        } catch {
            try? fileManager.moveItem(at: destinationDirectory, to: sourceDirectory)
            throw error
        }
    }

    static func stagePhotoForDeletion(
        id: UUID,
        originalRelativePath: String,
        thumbnailRelativePath: String,
        fileManager: FileManager = .default
    ) throws -> StagedDeletion {
        guard
            let originalURL = url(
                forRelativePath: originalRelativePath,
                fileManager: fileManager
            ),
            let thumbnailURL = url(
                forRelativePath: thumbnailRelativePath,
                fileManager: fileManager
            )
        else {
            throw MemoryPhotoStorageError.invalidStoredPath
        }

        let itemDirectory = originalURL
            .deletingLastPathComponent()
            .standardizedFileURL
        guard
            thumbnailURL.deletingLastPathComponent().standardizedFileURL == itemDirectory,
            itemDirectory.lastPathComponent == id.uuidString,
            fileManager.fileExists(atPath: originalURL.path),
            fileManager.fileExists(atPath: thumbnailURL.path)
        else {
            throw MemoryPhotoStorageError.storedPhotoMissing
        }

        let trashDirectory = try rootDirectory(fileManager: fileManager)
            .appendingPathComponent(".Trash", isDirectory: true)
        try fileManager.createDirectory(
            at: trashDirectory,
            withIntermediateDirectories: true
        )

        let stagedDirectory = trashDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.moveItem(at: itemDirectory, to: stagedDirectory)

        return StagedDeletion(
            originalDirectory: itemDirectory,
            stagedDirectory: stagedDirectory
        )
    }

    static func finishDeletion(
        _ deletion: StagedDeletion,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: deletion.stagedDirectory.path) else {
            return
        }
        try fileManager.removeItem(at: deletion.stagedDirectory)
    }

    static func rollbackDeletion(
        _ deletion: StagedDeletion,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: deletion.stagedDirectory.path) else {
            return
        }
        guard !fileManager.fileExists(atPath: deletion.originalDirectory.path) else {
            throw MemoryPhotoStorageError.destinationAlreadyExists
        }

        try fileManager.createDirectory(
            at: deletion.originalDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(
            at: deletion.stagedDirectory,
            to: deletion.originalDirectory
        )
    }

    static func removeItemDirectory(folderID: String, id: UUID) {
        guard let root = try? rootDirectory() else { return }
        let directory = root
            .appendingPathComponent(safePathComponent(folderID), isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }

    private static func rootDirectory(fileManager: FileManager = .default) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = applicationSupport.appendingPathComponent(rootDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func itemDirectory(
        folderID: String,
        id: UUID,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try rootDirectory(fileManager: fileManager)
            .appendingPathComponent(safePathComponent(folderID), isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func relativePath(
        for url: URL,
        fileManager: FileManager = .default
    ) throws -> String {
        let rootPath = try rootDirectory(fileManager: fileManager).standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else {
            throw MemoryPhotoStorageError.invalidStoredPath
        }
        return String(filePath.dropFirst(rootPath.count + 1))
    }

    private static func url(
        forRelativePath relativePath: String,
        fileManager: FileManager = .default
    ) -> URL? {
        guard
            !relativePath.isEmpty,
            !relativePath.hasPrefix("/"),
            !relativePath.split(separator: "/").contains(".."),
            let root = try? rootDirectory(fileManager: fileManager)
        else {
            return nil
        }

        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else { return nil }
        return url
    }

    private static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }

    private static func preferredFilenameExtension(for source: CGImageSource) -> String {
        guard
            let typeIdentifier = CGImageSourceGetType(source) as String?,
            let imageType = UTType(typeIdentifier),
            let fileExtension = imageType.preferredFilenameExtension
        else {
            return "jpg"
        }
        return fileExtension
    }

    private static func thumbnailData(
        from source: CGImageSource,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }

        return UIImage(cgImage: thumbnail).jpegData(
            compressionQuality: compressionQuality
        )
    }
}

@MainActor
enum MemoryPhotoRecorder {
    static func record(
        photoData: Data,
        capturedAt: Date = .now,
        sourceAssetLocalIdentifier: String? = nil,
        importOrigin: MemoryPhotoImportOrigin = .appCamera,
        modelContext: ModelContext
    ) throws -> RecordedMemoryPhoto {
        let id = UUID()
        let folder = MemoryPhotoFolder.uncategorized
        let storedPhoto = try MemoryPhotoStorage.store(
            photoData: photoData,
            folderID: folder.rawValue,
            id: id
        )
        let memoryPhoto = MemoryPhoto(
            id: id,
            folderID: folder.rawValue,
            originalRelativePath: storedPhoto.originalRelativePath,
            thumbnailRelativePath: storedPhoto.thumbnailRelativePath,
            capturedAt: capturedAt,
            sourceAssetLocalIdentifier: sourceAssetLocalIdentifier,
            importOrigin: importOrigin
        )

        modelContext.insert(memoryPhoto)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(memoryPhoto)
            MemoryPhotoStorage.removeItemDirectory(folderID: folder.rawValue, id: id)
            throw error
        }

        return RecordedMemoryPhoto(
            id: memoryPhoto.id,
            thumbnailRelativePath: memoryPhoto.thumbnailRelativePath
        )
    }
}
