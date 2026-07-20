import ActivityKit
import Foundation

enum CameraActivityPhase: String, Codable, Hashable {
    case cameraActive
    case completed

    var statusText: String {
        switch self {
        case .cameraActive:
            "선택한 사진을 참고 중"
        case .completed:
            "촬영이 완료되었습니다"
        }
    }
}

struct CameraActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: CameraActivityPhase
        var thumbnailIDs: [String]
        var selectedPhotoCount: Int
        var completedAt: Date?
    }

    let sessionID: String
    let contextTitle: String
}

enum CameraActivitySharedStorage {
    static let appGroupIdentifier = "group.com.folitune.joheulttaeda"
    static let thumbnailDirectoryName = "LiveActivityThumbnails"

    static func thumbnailDirectoryURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        return containerURL.appendingPathComponent(
            thumbnailDirectoryName,
            isDirectory: true
        )
    }

    static func thumbnailURL(for id: String) -> URL? {
        thumbnailDirectoryURL()?.appendingPathComponent(id, isDirectory: false)
    }
}
