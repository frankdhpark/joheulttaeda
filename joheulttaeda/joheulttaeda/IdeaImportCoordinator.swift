import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import LinkPresentation
import SwiftData
import UniformTypeIdentifiers
import UIKit

enum IdeaFolderSnapshotStore {
    static func writeDefaultSnapshot(fileManager: FileManager = .default) throws {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: IdeaImportAppGroup.identifier
        ) else {
            throw IdeaImportError.appGroupUnavailable
        }

        let target = container.appendingPathComponent(IdeaImportAppGroup.folderSnapshotFileName)
        let data = try JSONEncoder.ideaImportEncoder().encode(IdeaFolderSnapshot.defaults)
        try data.write(to: target, options: .atomic)
    }
}

private struct ResolvedInstagramMediaResponse: Decodable {
    let assets: [ResolvedInstagramMediaAsset]
}

private struct ResolvedInstagramMediaAsset: Decodable {
    let url: URL
    let mediaType: IncomingMediaType
}

private struct ResolvedInstagramMediaRequest: Encodable {
    let sourceURL: URL
}

private struct WorkingImportAttachment {
    let mediaType: IncomingMediaType
    let fileURL: URL?
}

@MainActor
final class IdeaImportCoordinator {
    static let shared = IdeaImportCoordinator()

    private let fileManager: FileManager
    private let session: URLSession
    private var isImporting = false
    private var attemptedPreviewItemIDs: Set<UUID> = []

    init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
    }

    func consumePendingImports(modelContext: ModelContext) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        do {
            try IdeaFolderSnapshotStore.writeDefaultSnapshot(fileManager: fileManager)
            let jobs = try pendingJobDirectories()

            for jobDirectory in jobs {
                do {
                    try await process(jobDirectory: jobDirectory, modelContext: modelContext)
                    try fileManager.removeItem(at: jobDirectory)
                } catch {
                    // 가져오기가 완전히 끝나기 전에는 작업 폴더를 남겨 다음 활성화 때 재시도합니다.
                    print("Idea import failed for \(jobDirectory.lastPathComponent): \(error.localizedDescription)")
                }
            }

            await backfillMissingLinkPreviews(modelContext: modelContext)
        } catch {
            print("Unable to consume Idea imports: \(error.localizedDescription)")
        }
    }

    private func pendingJobDirectories() throws -> [URL] {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: IdeaImportAppGroup.identifier
        ) else {
            throw IdeaImportError.appGroupUnavailable
        }

        let incoming = container.appendingPathComponent(
            IdeaImportAppGroup.incomingDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: incoming, withIntermediateDirectories: true)

        return try fileManager.contentsOfDirectory(
            at: incoming,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted {
            let lhs = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate
            let rhs = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate
            return (lhs ?? .distantPast) < (rhs ?? .distantPast)
        }
    }

    private func process(jobDirectory: URL, modelContext: ModelContext) async throws {
        let manifestURL = jobDirectory.appendingPathComponent(IdeaImportAppGroup.manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw IdeaImportError.invalidManifest
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder.ideaImportDecoder().decode(
            IdeaImportManifest.self,
            from: manifestData
        )
        let folderID = validatedFolderID(manifest.destinationFolderID)
        let attachments = try await workingAttachments(for: manifest, jobDirectory: jobDirectory)

        guard !attachments.isEmpty else {
            throw IdeaImportError.invalidManifest
        }

        for (index, attachment) in attachments.enumerated() {
            switch attachment.mediaType {
            case .image, .video:
                guard let fileURL = attachment.fileURL else {
                    throw IdeaImportError.invalidIncomingPath
                }
                try await importFile(
                    fileURL,
                    mediaType: attachment.mediaType,
                    folderID: folderID,
                    sourceURL: manifest.sourceURL,
                    sourceIndex: index,
                    importedAt: manifest.createdAt,
                    modelContext: modelContext
                )
            case .instagramURL:
                guard let sourceURL = manifest.sourceURL else {
                    throw IdeaImportError.invalidManifest
                }
                try await importLink(
                    sourceURL,
                    folderID: folderID,
                    importedAt: manifest.createdAt,
                    modelContext: modelContext
                )
            }
        }
    }

    private func workingAttachments(
        for manifest: IdeaImportManifest,
        jobDirectory: URL
    ) async throws -> [WorkingImportAttachment] {
        var localAttachments: [WorkingImportAttachment] = []

        for attachment in manifest.attachments where attachment.mediaType != .instagramURL {
            guard let relativePath = attachment.relativePath else {
                throw IdeaImportError.invalidIncomingPath
            }
            let fileName = URL(fileURLWithPath: relativePath).lastPathComponent
            guard fileName == relativePath else {
                throw IdeaImportError.invalidIncomingPath
            }

            let fileURL = jobDirectory.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw IdeaImportError.invalidIncomingPath
            }
            localAttachments.append(
                WorkingImportAttachment(mediaType: attachment.mediaType, fileURL: fileURL)
            )
        }

        if !localAttachments.isEmpty {
            return localAttachments
        }

        guard let sourceURL = manifest.sourceURL else {
            return manifest.attachments.map {
                WorkingImportAttachment(mediaType: $0.mediaType, fileURL: nil)
            }
        }

        if let resolverURL = instagramResolverURL() {
            let resolved = try await resolveInstagramMedia(
                sourceURL: sourceURL,
                resolverURL: resolverURL,
                jobDirectory: jobDirectory
            )
            if !resolved.isEmpty {
                return resolved
            }
        }

        return [WorkingImportAttachment(mediaType: .instagramURL, fileURL: nil)]
    }

    private func resolveInstagramMedia(
        sourceURL: URL,
        resolverURL: URL,
        jobDirectory: URL
    ) async throws -> [WorkingImportAttachment] {
        var request = URLRequest(url: resolverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ResolvedInstagramMediaRequest(sourceURL: sourceURL))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let resolved = try JSONDecoder().decode(ResolvedInstagramMediaResponse.self, from: data)
        var attachments: [WorkingImportAttachment] = []

        for (index, asset) in resolved.assets.enumerated() {
            guard asset.url.scheme?.lowercased() == "https",
                  asset.mediaType == .image || asset.mediaType == .video else {
                continue
            }

            let (temporaryURL, downloadResponse) = try await session.download(from: asset.url)
            guard let httpResponse = downloadResponse as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let fallbackExtension = asset.mediaType == .image ? "jpg" : "mp4"
            let remoteExtension = asset.url.pathExtension.lowercased()
            let fileExtension = remoteExtension.isEmpty ? fallbackExtension : remoteExtension
            let destination = jobDirectory.appendingPathComponent("resolved-\(index).\(fileExtension)")
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporaryURL, to: destination)
            attachments.append(
                WorkingImportAttachment(mediaType: asset.mediaType, fileURL: destination)
            )
        }

        return attachments
    }

    private func importFile(
        _ sourceFile: URL,
        mediaType: IncomingMediaType,
        folderID: String,
        sourceURL: URL?,
        sourceIndex: Int,
        importedAt: Date,
        modelContext: ModelContext
    ) async throws {
        try validateFile(sourceFile, mediaType: mediaType)
        let hash = try sha256(of: sourceFile)
        let deduplicationKey = "file:\(hash)"
        guard try !containsItem(with: deduplicationKey, modelContext: modelContext) else { return }

        let itemID = UUID()
        let itemDirectory = try IdeaMediaStorage.itemDirectory(
            folderID: folderID,
            itemID: itemID,
            fileManager: fileManager
        )
        let fallbackExtension = mediaType == .image ? "jpg" : "mp4"
        let sourceExtension = sourceFile.pathExtension.lowercased()
        let fileExtension = sourceExtension.isEmpty ? fallbackExtension : sourceExtension
        let originalURL = itemDirectory.appendingPathComponent("original.\(fileExtension)")
        let thumbnailURL = itemDirectory.appendingPathComponent("thumbnail.jpg")

        do {
            try fileManager.copyItem(at: sourceFile, to: originalURL)
            switch mediaType {
            case .image:
                try createImageThumbnail(sourceURL: originalURL, outputURL: thumbnailURL)
            case .video:
                try await createVideoThumbnail(videoURL: originalURL, outputURL: thumbnailURL)
            case .instagramURL:
                throw IdeaImportError.unsupportedMedia
            }

            let kind: IdeaMediaKind = mediaType == .image ? .image : .video
            let item = IdeaMediaItem(
                id: itemID,
                folderID: folderID,
                kind: kind,
                title: mediaTitle(kind: kind, sourceURL: sourceURL, index: sourceIndex),
                originalRelativePath: try IdeaMediaStorage.relativePath(
                    for: originalURL,
                    fileManager: fileManager
                ),
                thumbnailRelativePath: try IdeaMediaStorage.relativePath(
                    for: thumbnailURL,
                    fileManager: fileManager
                ),
                sourceURL: sourceURL,
                importedAt: importedAt,
                deduplicationKey: deduplicationKey
            )
            modelContext.insert(item)
            try modelContext.save()
        } catch {
            try? fileManager.removeItem(at: itemDirectory)
            throw error
        }
    }

    private func importLink(
        _ sourceURL: URL,
        folderID: String,
        importedAt: Date,
        modelContext: ModelContext
    ) async throws {
        let normalizedURL = normalizedInstagramURL(sourceURL)
        let deduplicationKey = "link:\(normalizedURL.absoluteString)"

        if let existingItem = try item(
            with: deduplicationKey,
            modelContext: modelContext
        ) {
            await populateLinkPreviewIfNeeded(
                for: existingItem,
                modelContext: modelContext
            )
            return
        }

        let item = IdeaMediaItem(
            folderID: folderID,
            kind: .link,
            title: mediaTitle(kind: .link, sourceURL: normalizedURL, index: 0),
            originalRelativePath: nil,
            thumbnailRelativePath: nil,
            sourceURL: normalizedURL,
            importedAt: importedAt,
            deduplicationKey: deduplicationKey
        )
        modelContext.insert(item)
        try modelContext.save()

        // 링크 저장은 썸네일 조회 결과와 무관하게 성공해야 합니다.
        await populateLinkPreviewIfNeeded(for: item, modelContext: modelContext)
    }

    private func backfillMissingLinkPreviews(modelContext: ModelContext) async {
        let linkKind = IdeaMediaKind.link.rawValue
        let descriptor = FetchDescriptor<IdeaMediaItem>(
            predicate: #Predicate { item in
                item.kindRawValue == linkKind && item.thumbnailRelativePath == nil
            },
            sortBy: [SortDescriptor(\IdeaMediaItem.importedAt, order: .reverse)]
        )

        do {
            let candidates = try modelContext.fetch(descriptor)
                .filter { !attemptedPreviewItemIDs.contains($0.id) }
                .prefix(4)

            for item in candidates {
                await populateLinkPreviewIfNeeded(for: item, modelContext: modelContext)
            }
        } catch {
            print("Unable to find Idea links needing previews: \(error.localizedDescription)")
        }
    }

    private func populateLinkPreviewIfNeeded(
        for item: IdeaMediaItem,
        modelContext: ModelContext
    ) async {
        guard item.kind == .link,
              item.thumbnailRelativePath == nil,
              !attemptedPreviewItemIDs.contains(item.id),
              let sourceURL = item.sourceURL else {
            return
        }

        attemptedPreviewItemIDs.insert(item.id)
        guard let image = await fetchLinkPreviewImage(for: sourceURL) else { return }

        do {
            let itemDirectory = try IdeaMediaStorage.itemDirectory(
                folderID: item.folderID,
                itemID: item.id,
                fileManager: fileManager
            )
            let thumbnailURL = itemDirectory.appendingPathComponent("thumbnail.jpg")
            try writeLinkThumbnail(image, to: thumbnailURL)

            let relativePath = try IdeaMediaStorage.relativePath(
                for: thumbnailURL,
                fileManager: fileManager
            )
            item.thumbnailRelativePath = relativePath

            do {
                try modelContext.save()
            } catch {
                item.thumbnailRelativePath = nil
                try? fileManager.removeItem(at: thumbnailURL)
                throw error
            }
        } catch {
            // 미리보기 실패는 이미 저장된 링크를 무효화하지 않습니다.
            print("Unable to save preview for \(sourceURL.absoluteString): \(error.localizedDescription)")
        }
    }

    private func fetchLinkPreviewImage(for sourceURL: URL) async -> UIImage? {
        let metadataProvider = LPMetadataProvider()
        metadataProvider.shouldFetchSubresources = true
        metadataProvider.timeout = 10

        let metadata: LPLinkMetadata? = await withCheckedContinuation { continuation in
            metadataProvider.startFetchingMetadata(for: sourceURL) { metadata, _ in
                continuation.resume(returning: metadata)
            }
        }

        guard let imageProvider = metadata?.imageProvider,
              imageProvider.canLoadObject(ofClass: UIImage.self) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            imageProvider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    private func writeLinkThumbnail(_ image: UIImage, to outputURL: URL) throws {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw IdeaImportError.thumbnailCreationFailed
        }

        let maximumPixelSize: CGFloat = 640
        let scale = min(1, maximumPixelSize / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let thumbnail = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = thumbnail.jpegData(compressionQuality: 0.82) else {
            throw IdeaImportError.thumbnailCreationFailed
        }
        try data.write(to: outputURL, options: .atomic)
    }

    private func containsItem(
        with deduplicationKey: String,
        modelContext: ModelContext
    ) throws -> Bool {
        try item(with: deduplicationKey, modelContext: modelContext) != nil
    }

    private func item(
        with deduplicationKey: String,
        modelContext: ModelContext
    ) throws -> IdeaMediaItem? {
        let key = deduplicationKey
        var descriptor = FetchDescriptor<IdeaMediaItem>(
            predicate: #Predicate { item in
                item.deduplicationKey == key
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func validateFile(_ url: URL, mediaType: IncomingMediaType) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw IdeaImportError.invalidIncomingPath }

        let maximumSize = mediaType == .image ? 80 * 1_024 * 1_024 : 750 * 1_024 * 1_024
        guard (values.fileSize ?? 0) <= maximumSize else { throw IdeaImportError.fileTooLarge }

        guard let type = UTType(filenameExtension: url.pathExtension) else { return }
        switch mediaType {
        case .image where !type.conforms(to: .image):
            throw IdeaImportError.unsupportedMedia
        case .video where !(type.conforms(to: .movie) || type.conforms(to: .video)):
            throw IdeaImportError.unsupportedMedia
        default:
            break
        }
    }

    private func createImageThumbnail(sourceURL: URL, outputURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1_600
                ] as CFDictionary
              ),
              let data = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.84) else {
            throw IdeaImportError.thumbnailCreationFailed
        }
        try data.write(to: outputURL, options: .atomic)
    }

    private func createVideoThumbnail(videoURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1_600, height: 1_600)

        let result = try await generator.image(
            at: CMTime(seconds: 0.5, preferredTimescale: 600)
        )
        guard let data = UIImage(cgImage: result.image).jpegData(compressionQuality: 0.84) else {
            throw IdeaImportError.thumbnailCreationFailed
        }
        try data.write(to: outputURL, options: .atomic)
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func validatedFolderID(_ folderID: String) -> String {
        IdeaFolderSnapshot.defaults.contains(where: { $0.id == folderID })
            ? folderID
            : "idea-inbox"
    }

    private func instagramResolverURL() -> URL? {
        guard let rawValue = Bundle.main.object(
            forInfoDictionaryKey: "InstagramImportResolverURL"
        ) as? String else {
            return nil
        }
        return URL(string: rawValue)
    }

    private func normalizedInstagramURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.fragment = nil
        components.query = nil
        components.host = components.host?.lowercased()
        return components.url ?? url
    }

    private func mediaTitle(kind: IdeaMediaKind, sourceURL: URL?, index: Int) -> String {
        let suffix = index > 0 ? " \(index + 1)" : ""
        switch kind {
        case .image:
            return "Instagram 사진\(suffix)"
        case .video:
            return "Instagram 릴스\(suffix)"
        case .link:
            let path = sourceURL?.path.lowercased() ?? ""
            return path.contains("/reel/") ? "Instagram 릴스" : "Instagram 게시물"
        }
    }
}
