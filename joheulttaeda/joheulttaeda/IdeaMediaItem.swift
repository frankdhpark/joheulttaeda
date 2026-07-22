import Foundation
import SwiftData

enum IdeaMediaKind: String, Codable {
    case image
    case video
    case link
}

@Model
final class IdeaMediaItem {
    @Attribute(.unique) var id: UUID
    var folderID: String
    var kindRawValue: String
    var title: String
    var originalRelativePath: String?
    var thumbnailRelativePath: String?
    var sourceURLString: String?
    var importedAt: Date
    @Attribute(.unique) var deduplicationKey: String

    init(
        id: UUID = UUID(),
        folderID: String,
        kind: IdeaMediaKind,
        title: String,
        originalRelativePath: String?,
        thumbnailRelativePath: String?,
        sourceURL: URL?,
        importedAt: Date = Date(),
        deduplicationKey: String
    ) {
        self.id = id
        self.folderID = folderID
        self.kindRawValue = kind.rawValue
        self.title = title
        self.originalRelativePath = originalRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.sourceURLString = sourceURL?.absoluteString
        self.importedAt = importedAt
        self.deduplicationKey = deduplicationKey
    }

    var kind: IdeaMediaKind {
        IdeaMediaKind(rawValue: kindRawValue) ?? .link
    }

    var sourceURL: URL? {
        sourceURLString.flatMap(URL.init(string:))
    }
}
