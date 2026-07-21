import ActivityKit
import OSLog
import UIKit

enum CameraLiveActivityStartError: LocalizedError {
    case activitiesDisabled
    case noSelectedPhotos
    case sharedStorageUnavailable
    case thumbnailCreationFailed
    case activityDidNotBecomeActive
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .activitiesDisabled:
            "설정에서 joheulttaeda의 Live Activity를 활성화한 후 다시 시도해주세요."
        case .noSelectedPhotos:
            "Dynamic Island에 표시할 사진을 다시 선택해주세요."
        case .sharedStorageUnavailable:
            "선택 사진을 Live Activity와 공유할 수 없습니다. App Group 설정을 확인해주세요."
        case .thumbnailCreationFailed:
            "선택 사진의 Live Activity 미리 보기를 만들지 못했습니다. 다시 시도해주세요."
        case .activityDidNotBecomeActive:
            "Live Activity가 활성 상태로 전환되지 않았습니다. 기기의 Live Activity 설정을 확인해주세요."
        case let .requestFailed(message):
            "Live Activity를 시작하지 못했습니다. \(message)"
        }
    }
}

@MainActor
final class CameraLiveActivityManager {
    static let shared = CameraLiveActivityManager()

    private let logger = Logger(
        subsystem: "com.folitune.joheulttaeda",
        category: "CameraLiveActivity"
    )
    private var currentActivity: Activity<CameraActivityAttributes>?
    private var dismissalTask: Task<Void, Never>?
    private var currentThumbnailIDs: [String] = []

    private init() {}

    func start(
        selectedImages: [UIImage],
        selectedPhotoCount: Int,
        contextTitle: String
    ) async throws {
        dismissalTask?.cancel()
        await endOutstandingActivities()
        removeStoredThumbnails()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw CameraLiveActivityStartError.activitiesDisabled
        }

        guard selectedPhotoCount > 0 else {
            throw CameraLiveActivityStartError.noSelectedPhotos
        }

        guard CameraActivitySharedStorage.thumbnailDirectoryURL() != nil else {
            throw CameraLiveActivityStartError.sharedStorageUnavailable
        }

        let thumbnailLimit = min(selectedPhotoCount, 8)
        guard selectedImages.count >= thumbnailLimit else {
            throw CameraLiveActivityStartError.noSelectedPhotos
        }

        let thumbnailIDs = selectedImages
            .prefix(thumbnailLimit)
            .compactMap(storeThumbnail)

        guard thumbnailIDs.count == thumbnailLimit else {
            removeThumbnails(ids: thumbnailIDs)
            throw CameraLiveActivityStartError.thumbnailCreationFailed
        }

        currentThumbnailIDs = thumbnailIDs

        let attributes = CameraActivityAttributes(
            sessionID: UUID().uuidString,
            contextTitle: contextTitle
        )
        let state = CameraActivityAttributes.ContentState(
            phase: .cameraActive,
            thumbnailIDs: thumbnailIDs,
            selectedPhotoCount: selectedPhotoCount,
            completedAt: nil
        )

        let activity: Activity<CameraActivityAttributes>

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: Date.now.addingTimeInterval(120),
                    relevanceScore: 1
                ),
                pushType: nil
            )
        } catch {
            removeCurrentThumbnails()
            logger.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
            throw CameraLiveActivityStartError.requestFailed(error.localizedDescription)
        }

        currentActivity = activity
        await Task.yield()

        guard activity.activityState == .active else {
            logger.error("Live Activity did not become active. State: \(String(describing: activity.activityState), privacy: .public)")
            await activity.end(activity.content, dismissalPolicy: .immediate)
            currentActivity = nil
            removeCurrentThumbnails()
            throw CameraLiveActivityStartError.activityDidNotBecomeActive
        }

        logger.info(
            "Live Activity started. ID: \(activity.id, privacy: .public), thumbnails: \(thumbnailIDs.count, privacy: .public)"
        )
    }

    func finish() async {
        guard let currentActivity else { return }

        let finalState = CameraActivityAttributes.ContentState(
            phase: .completed,
            thumbnailIDs: currentThumbnailIDs,
            selectedPhotoCount: currentActivity.content.state.selectedPhotoCount,
            completedAt: .now
        )
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: Date.now.addingTimeInterval(12),
            relevanceScore: 1
        )

        await currentActivity.update(
            finalContent,
            alertConfiguration: AlertConfiguration(
                title: "촬영이 완료되었습니다",
                body: "선택한 Idea 사진은 Dynamic Island에 잠시 더 표시됩니다.",
                sound: .default
            )
        )

        dismissalTask?.cancel()
        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self else { return }
            await self.endCurrentActivity(
                finalContent: finalContent,
                dismissalPolicy: .after(Date.now.addingTimeInterval(2))
            )
        }
    }

    func cancel() async {
        dismissalTask?.cancel()
        await endOutstandingActivities()
        removeStoredThumbnails()
    }

    private func endOutstandingActivities() async {
        for activity in Activity<CameraActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        removeCurrentThumbnails()
    }

    private func endCurrentActivity(
        finalContent: ActivityContent<CameraActivityAttributes.ContentState>? = nil,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async {
        guard let activity = currentActivity else { return }

        let content = finalContent ?? activity.content
        await activity.end(content, dismissalPolicy: dismissalPolicy)
        currentActivity = nil

        if dismissalPolicy == .immediate {
            removeCurrentThumbnails()
        } else {
            let thumbnailIDs = currentThumbnailIDs
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard let self else { return }
                self.removeThumbnails(ids: thumbnailIDs)
            }
        }
    }

    private func storeThumbnail(_ image: UIImage) -> String? {
        guard let directoryURL = CameraActivitySharedStorage.thumbnailDirectoryURL() else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let thumbnail = squareThumbnail(from: image, sideLength: 192)
            guard let data = thumbnail.jpegData(compressionQuality: 0.84) else { return nil }

            let id = "idea-selection-\(UUID().uuidString).jpg"
            let fileURL = directoryURL.appendingPathComponent(id)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            return id
        } catch {
            return nil
        }
    }

    private func squareThumbnail(from image: UIImage, sideLength: CGFloat) -> UIImage {
        let sourceSize = image.size
        let scale = max(sideLength / sourceSize.width, sideLength / sourceSize.height)
        let scaledSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let origin = CGPoint(
            x: (sideLength - scaledSize.width) / 2,
            y: (sideLength - scaledSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard

        return UIGraphicsImageRenderer(
            size: CGSize(width: sideLength, height: sideLength),
            format: format
        ).image { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }

    private func removeStoredThumbnails() {
        currentThumbnailIDs = []
        guard let directoryURL = CameraActivitySharedStorage.thumbnailDirectoryURL() else { return }
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private func removeCurrentThumbnails() {
        removeThumbnails(ids: currentThumbnailIDs)
        currentThumbnailIDs = []
    }

    private func removeThumbnails(ids: [String]) {
        for id in ids {
            guard let url = CameraActivitySharedStorage.thumbnailURL(for: id) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
