import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct CameraLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CameraActivityAttributes.self) { context in
            CameraLockScreenActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.12, green: 0.11, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CameraActivityIcon(phase: context.state.phase)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.selectedPhotoCount)")
                            .font(.headline.monospacedDigit())
                        Text("선택됨")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        CameraActivityPhotoGrid(
                            thumbnailIDs: context.state.thumbnailIDs,
                            totalCount: context.state.selectedPhotoCount,
                            cellSize: 27,
                            columns: 4
                        )
                        .frame(width: 117, height: 58, alignment: .leading)
                        .privacySensitive()

                        VStack(alignment: .leading, spacing: 3) {
                            Text(context.state.phase.statusText)
                                .font(.headline)
                            Text(context.attributes.contextTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                CameraActivityThumbnail(
                    thumbnailID: context.state.thumbnailIDs.first,
                    cornerRadius: 5
                )
                .frame(width: 22, height: 22)
                .privacySensitive()
            } compactTrailing: {
                Text("\(context.state.selectedPhotoCount)장")
                    .font(.caption2.bold())
            } minimal: {
                CameraActivityThumbnail(
                    thumbnailID: context.state.thumbnailIDs.first,
                    cornerRadius: 5
                )
                .frame(width: 22, height: 22)
                .privacySensitive()
            }
            .keylineTint(context.state.phase == .completed ? .green : .white)
        }
    }
}

private struct CameraLockScreenActivityView: View {
    let context: ActivityViewContext<CameraActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            CameraActivityPhotoGrid(
                thumbnailIDs: context.state.thumbnailIDs,
                totalCount: context.state.selectedPhotoCount,
                cellSize: 33,
                columns: 4
            )
                .frame(width: 144, height: 70, alignment: .leading)
                .privacySensitive()

            VStack(alignment: .leading, spacing: 5) {
                Label(
                    context.state.phase.statusText,
                    systemImage: context.state.phase == .completed ? "checkmark.circle.fill" : "camera.fill"
                )
                .font(.headline)

                Text(context.attributes.contextTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let completedAt = context.state.completedAt {
                    Text(completedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(context.state.selectedPhotoCount)장의 사진 선택됨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct CameraActivityIcon: View {
    let phase: CameraActivityPhase

    var body: some View {
        Image(systemName: phase == .completed ? "checkmark.circle.fill" : "camera.fill")
            .font(.title2.bold())
            .foregroundStyle(phase == .completed ? .green : .white)
            .frame(width: 46, height: 46)
            .background(.white.opacity(0.12), in: Circle())
    }
}

private struct CameraActivityThumbnail: View {
    let thumbnailID: String?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let image = loadThumbnail() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.90))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
        .clipped()
    }

    private func loadThumbnail() -> UIImage? {
        guard
            let thumbnailID,
            let url = CameraActivitySharedStorage.thumbnailURL(for: thumbnailID),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }

        return UIImage(data: data)
    }
}

private struct CameraActivityPhotoGrid: View {
    let thumbnailIDs: [String]
    let totalCount: Int
    let cellSize: CGFloat
    let columns: Int

    private var visibleIDs: [String] {
        Array(thumbnailIDs.prefix(8))
    }

    private var rows: [[String]] {
        stride(from: 0, to: visibleIDs.count, by: columns).map { start in
            Array(visibleIDs[start..<min(start + columns, visibleIDs.count)])
        }
    }

    var body: some View {
        Group {
            if visibleIDs.isEmpty {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "photo.stack.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.90))
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 4) {
                                ForEach(row, id: \.self) { thumbnailID in
                                    CameraActivityThumbnail(
                                        thumbnailID: thumbnailID,
                                        cornerRadius: 6
                                    )
                                    .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }

                    if totalCount > visibleIDs.count {
                        Text("+\(totalCount - visibleIDs.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.72), in: Capsule())
                    }
                }
            }
        }
    }
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: CameraActivityAttributes(
    sessionID: "preview",
    contextTitle: "Our Baby's First Amusement Park Trip"
)) {
    CameraLiveActivityWidget()
} contentStates: {
    CameraActivityAttributes.ContentState(
        phase: .cameraActive,
        thumbnailIDs: [],
        selectedPhotoCount: 2,
        completedAt: nil
    )
    CameraActivityAttributes.ContentState(
        phase: .completed,
        thumbnailIDs: [],
        selectedPhotoCount: 2,
        completedAt: .now
    )
}
