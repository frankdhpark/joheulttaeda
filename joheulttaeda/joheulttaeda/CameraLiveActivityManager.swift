import ActivityKit
import UIKit

@MainActor
final class CameraLiveActivityManager {
    static let shared = CameraLiveActivityManager()

    private var currentActivity: Activity<CameraActivityAttributes>?
    private var dismissalTask: Task<Void, Never>?
    private var currentThumbnailIDs: [String] = []

    private init() {}

    func start(
        selectedImages: [UIImage],
        selectedPhotoCount: Int,
        contextTitle: String
    ) async {
        dismissalTask?.cancel()
        await endOutstandingActivities()
        removeStoredThumbnails()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let thumbnailIDs = selectedImages
            .prefix(8)
            .compactMap(storeThumbnail)
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

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: Date.now.addingTimeInterval(120)
                ),
                pushType: nil
            )
        } catch {
            currentActivity = nil
            removeCurrentThumbnails()
        }
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
            staleDate: Date.now.addingTimeInterval(12)
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

            let thumbnail = squareThumbnail(from: image, sideLength: 96)
            guard let data = thumbnail.jpegData(compressionQuality: 0.76) else { return nil }

            let id = "idea-selection-\(UUID().uuidString).jpg"
            try data.write(to: directoryURL.appendingPathComponent(id), options: .atomic)
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

        return UIGraphicsImageRenderer(
            size: CGSize(width: sideLength, height: sideLength)
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
