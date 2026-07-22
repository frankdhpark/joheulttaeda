import Foundation

enum IdeaImportAppGroup {
    static let identifier = "group.com.folitune.joheulttaeda"
    static let incomingDirectoryName = "Incoming"
    static let folderSnapshotFileName = "folders.json"
    static let manifestFileName = "manifest.json"
}

struct IdeaFolderSnapshot: Codable, Hashable, Identifiable {
    let id: String
    let title: String

    static let defaults = [
        IdeaFolderSnapshot(id: "idea-inbox", title: "새 아이디어"),
        IdeaFolderSnapshot(id: "outing", title: "나들이"),
        IdeaFolderSnapshot(id: "nap", title: "낮잠"),
        IdeaFolderSnapshot(id: "food", title: "먹방"),
        IdeaFolderSnapshot(id: "walk", title: "산책"),
        IdeaFolderSnapshot(id: "swimming", title: "수영"),
        IdeaFolderSnapshot(id: "costume", title: "코스프레"),
        IdeaFolderSnapshot(id: "fashion", title: "패션")
    ]
}

enum IncomingMediaType: String, Codable {
    case image
    case video
    case instagramURL
}

struct IncomingAttachment: Codable, Hashable {
    let mediaType: IncomingMediaType
    let relativePath: String?
}

struct IdeaImportManifest: Codable, Identifiable {
    let id: UUID
    let destinationFolderID: String
    let sourceURL: URL?
    let attachments: [IncomingAttachment]
    let createdAt: Date
}

extension JSONEncoder {
    static func ideaImportEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static func ideaImportDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
