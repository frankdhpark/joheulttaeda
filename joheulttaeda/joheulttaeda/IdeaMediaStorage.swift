import Foundation
import UIKit

enum IdeaMediaStorage {
    private static let rootDirectoryName = "IdeaMedia"

    static func rootDirectory(fileManager: FileManager = .default) throws -> URL {
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

    static func itemDirectory(
        folderID: String,
        itemID: UUID,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try rootDirectory(fileManager: fileManager)
            .appendingPathComponent(safePathComponent(folderID), isDirectory: true)
            .appendingPathComponent(itemID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func relativePath(for url: URL, fileManager: FileManager = .default) throws -> String {
        let rootPath = try rootDirectory(fileManager: fileManager).standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else {
            throw IdeaImportError.invalidStoredPath
        }
        return String(filePath.dropFirst(rootPath.count + 1))
    }

    static func url(forRelativePath relativePath: String, fileManager: FileManager = .default) -> URL? {
        guard isSafeRelativePath(relativePath) else { return nil }
        guard let root = try? rootDirectory(fileManager: fileManager) else { return nil }
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else { return nil }
        return url
    }

    static func image(forRelativePath relativePath: String) -> UIImage? {
        guard let url = url(forRelativePath: relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func removeItemDirectory(for item: IdeaMediaItem) {
        guard let path = item.originalRelativePath ?? item.thumbnailRelativePath else { return }
        guard let fileURL = url(forRelativePath: path) else { return }
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    private static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }

    private static func isSafeRelativePath(_ value: String) -> Bool {
        !value.isEmpty
            && !value.hasPrefix("/")
            && !value.split(separator: "/").contains("..")
    }
}

enum IdeaImportError: LocalizedError {
    case appGroupUnavailable
    case invalidManifest
    case invalidIncomingPath
    case invalidStoredPath
    case unsupportedMedia
    case fileTooLarge
    case thumbnailCreationFailed

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "공유 저장 공간을 열 수 없습니다."
        case .invalidManifest:
            "가져오기 요청을 읽을 수 없습니다."
        case .invalidIncomingPath:
            "공유된 파일 경로가 올바르지 않습니다."
        case .invalidStoredPath:
            "저장된 미디어 경로가 올바르지 않습니다."
        case .unsupportedMedia:
            "지원하지 않는 미디어 형식입니다."
        case .fileTooLarge:
            "공유된 파일이 허용 크기를 초과했습니다."
        case .thumbnailCreationFailed:
            "미디어 미리보기를 만들 수 없습니다."
        }
    }
}
