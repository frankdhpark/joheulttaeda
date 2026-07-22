import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UIKit

struct MemorySectionView: View {
    let onHome: () -> Void

    @Query(sort: \MemoryPhoto.capturedAt, order: .reverse)
    private var capturedPhotos: [MemoryPhoto]
    @State private var selectedMode: MemoryMode = .threads
    @State private var presentedFolder: MemoryPhotoFolder?
    @State private var photoImportSettingsArePresented = false

    private func photos(in folder: MemoryPhotoFolder) -> [MemoryPhoto] {
        capturedPhotos.filter {
            $0.folderID == folder.rawValue
                || (folder == .uncategorized && $0.folderID.isEmpty)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MemoryPalette.background
                .ignoresSafeArea()

            Group {
                switch selectedMode {
                case .moments:
                    MomentsMemoryView()
                case .days:
                    DaysMemoryView()
                case .months:
                    MonthsMemoryView()
                case .threads:
                    ThreadsMemoryView(
                        capturedPhotos: capturedPhotos,
                        onFolderOpen: { presentedFolder = $0 },
                        onSettingsOpen: {
                            photoImportSettingsArePresented = true
                        }
                    )
                }
            }
            .transition(.opacity)

            LinearGradient(
                colors: [.clear, MemoryPalette.background.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 78)
            .allowsHitTesting(false)

            MemoryNavigation(selectedMode: $selectedMode, onHome: onHome)
                .padding(.bottom, 8)
        }
        .background(MemoryPalette.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Memory")
        .fullScreenCover(item: $presentedFolder) { folder in
            MemoryPhotoFolderView(
                folder: folder,
                photos: photos(in: folder)
            )
        }
        .sheet(isPresented: $photoImportSettingsArePresented) {
            MemoryPhotoImportSettingsView()
        }
    }
}

private enum MemoryMode: String, CaseIterable, Identifiable {
    case moments = "Moments"
    case days = "Days"
    case months = "Months"
    case threads = "Threads"

    var id: String { rawValue }
}

private enum MemoryPalette {
    static let background = Color(red: 0.982, green: 0.959, blue: 0.945)
    static let paper = Color(red: 0.998, green: 0.995, blue: 0.991)
    static let text = Color(red: 0.45, green: 0.42, blue: 0.39)
    static let subdued = Color(red: 0.68, green: 0.65, blue: 0.62)
    static let navigation = Color(red: 0.91, green: 0.88, blue: 0.84)
    static let scrapbook = Color(red: 0.84, green: 0.84, blue: 0.83)
}

private struct MemoryNavigation: View {
    @Binding var selectedMode: MemoryMode
    let onHome: () -> Void

    var body: some View {
        HStack(spacing: 1) {
            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 34, height: 32)
            }
            .accessibilityLabel("홈")

            ForEach(MemoryMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.17)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .frame(width: width(for: mode), height: 32)
                        .background {
                            if selectedMode == mode {
                                Capsule()
                                    .fill(.white.opacity(0.94))
                            }
                        }
                }
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
        .foregroundStyle(MemoryPalette.text)
        .padding(3)
        .background(MemoryPalette.navigation, in: Capsule())
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func width(for mode: MemoryMode) -> CGFloat {
        switch mode {
        case .moments: 62
        case .days: 44
        case .months: 55
        case .threads: 58
        }
    }
}

private struct ThreadsMemoryView: View {
    let capturedPhotos: [MemoryPhoto]
    let onFolderOpen: (MemoryPhotoFolder) -> Void
    let onSettingsOpen: () -> Void

    @State private var filter = "All"

    private func photos(in folder: MemoryPhotoFolder) -> [MemoryPhoto] {
        capturedPhotos.filter {
            $0.folderID == folder.rawValue
                || (folder == .uncategorized && $0.folderID.isEmpty)
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        filterButton("All")
                        filterButton("Film")
                        filterButton("Scrapbook")
                    }
                    .padding(3)
                    .background(MemoryPalette.navigation, in: Capsule())
                    .fixedSize()

                    Spacer()

                    Button(action: onSettingsOpen) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MemoryPalette.text)
                            .frame(width: 32, height: 32)
                            .background(MemoryPalette.navigation, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Memory 가져오기 설정")
                }

                Text("Folders")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)

                LazyVStack(spacing: 10) {
                    ForEach(MemoryPhotoFolder.allCases) { folder in
                        Button {
                            onFolderOpen(folder)
                        } label: {
                            MemoryPhotoFolderCard(
                                folder: folder,
                                photos: photos(in: folder)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("\(folder.title) 사진 목록을 엽니다")
                    }
                }

                Text("Recommended")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ThreadCard(style: .film, tape: false)
                    ThreadCard(style: .scrapbook, tape: true)
                    ThreadCard(style: .scrapbook, tape: true)
                    ThreadCard(style: .film, tape: false)
                }

                Text("Same Pose, Different Day")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)
                    .padding(.top, 2)

                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ThreadCard(style: .film, tape: false)
                            .frame(width: 142)
                        ThreadCard(style: .film, tape: false)
                            .frame(width: 142)
                        ThreadCard(style: .film, tape: false)
                            .frame(width: 142)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 36)
            .padding(.top, 16)
            .padding(.bottom, 92)
        }
        .scrollIndicators(.hidden)
    }

    private func filterButton(_ title: String) -> some View {
        Button {
            filter = title
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(MemoryPalette.text)
                .frame(width: title == "Scrapbook" ? 78 : 50, height: 24)
                .background {
                    if filter == title {
                        Capsule().fill(.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct MemoryPhotoImportSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(MemoryPhotoLibraryImporter.automaticImportEnabledDefaultsKey)
    private var automaticImportIsEnabled = false

    @State private var authorizationStatus =
        MemoryPhotoLibraryImporter.authorizationStatus
    @State private var settingIsChanging = false
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var pickerImportIsRunning = false
    @State private var pickerImportMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "기본 카메라 사진 자동 가져오기",
                        isOn: automaticImportBinding
                    )
                    .disabled(settingIsChanging)

                    LabeledContent("사진 접근 권한", value: authorizationTitle)
                } footer: {
                    Text(
                        "기능을 켠 이후 기본 사진 보관함에 추가된 새 이미지만 "
                            + "Memory로 복사하고 Vision으로 자동 분류합니다. "
                            + "스크린샷과 영상은 제외됩니다."
                    )
                }

                if authorizationStatus == .limited {
                    Section("제한된 접근") {
                        PhotosPicker(
                            selection: $selectedPickerItems,
                            maxSelectionCount: 20,
                            matching: .images
                        ) {
                            Label(
                                pickerImportIsRunning
                                    ? "사진을 가져오는 중…"
                                    : "사진을 직접 선택해서 가져오기",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }
                        .disabled(pickerImportIsRunning)

                        Text(
                            "제한된 접근에서는 새 사진을 자동으로 확인할 수 없습니다. "
                                + "자동 가져오기를 사용하려면 설정에서 전체 접근을 허용해주세요."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                if authorizationStatus == .denied
                    || authorizationStatus == .restricted
                    || authorizationStatus == .limited {
                    Section {
                        Button("iOS 설정에서 사진 접근 변경") {
                            guard let settingsURL = URL(
                                string: UIApplication.openSettingsURLString
                            ) else { return }
                            openURL(settingsURL)
                        }
                    }
                }

                if let pickerImportMessage {
                    Section("가져오기 결과") {
                        Text(pickerImportMessage)
                    }
                }
            }
            .navigationTitle("Memory 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedPickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPickerItems(items)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            authorizationStatus = MemoryPhotoLibraryImporter.authorizationStatus
            if authorizationStatus != .authorized {
                automaticImportIsEnabled = false
            }
        }
    }

    private var automaticImportBinding: Binding<Bool> {
        Binding(
            get: { automaticImportIsEnabled },
            set: { requestedValue in
                guard !settingIsChanging else { return }
                settingIsChanging = true

                Task { @MainActor in
                    let status = await MemoryPhotoLibraryImporter
                        .setAutomaticImportEnabled(requestedValue)
                    authorizationStatus = status
                    automaticImportIsEnabled = requestedValue && status == .authorized

                    if automaticImportIsEnabled {
                        await MemoryPhotoLibraryImporter.importNewPhotos(
                            modelContext: modelContext
                        )
                    }

                    settingIsChanging = false
                }
            }
        )
    }

    private var authorizationTitle: String {
        switch authorizationStatus {
        case .authorized:
            "전체 접근"
        case .limited:
            "제한된 접근"
        case .denied:
            "허용 안 함"
        case .restricted:
            "접근 제한됨"
        case .notDetermined:
            "아직 요청하지 않음"
        @unknown default:
            "확인할 수 없음"
        }
    }

    private func importPickerItems(_ items: [PhotosPickerItem]) {
        pickerImportIsRunning = true
        pickerImportMessage = nil

        Task { @MainActor in
            let result = await MemoryPhotoLibraryImporter.importSelectedPhotos(
                items,
                modelContext: modelContext
            )
            selectedPickerItems = []
            pickerImportIsRunning = false

            var messages = ["\(result.importedCount)장 가져옴"]
            if result.skippedCount > 0 {
                messages.append("중복 \(result.skippedCount)장 제외")
            }
            if result.failedCount > 0 {
                messages.append("\(result.failedCount)장 실패")
            }
            pickerImportMessage = messages.joined(separator: " · ")
        }
    }
}

private struct MemoryPhotoFolderCard: View {
    let folder: MemoryPhotoFolder
    let photos: [MemoryPhoto]

    private var previewPhotos: [MemoryPhoto] {
        Array(photos.prefix(4))
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MemoryPalette.scrapbook)

                if previewPhotos.isEmpty {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(MemoryPalette.text.opacity(0.60))
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 3),
                            GridItem(.flexible(), spacing: 3)
                        ],
                        spacing: 3
                    ) {
                        ForEach(previewPhotos) { photo in
                            MemoryPhotoThumbnail(photo: photo)
                        }
                    }
                    .padding(5)
                }
            }
            .frame(width: 104, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(folder.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Text("\(photos.count)장")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(MemoryPalette.subdued)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MemoryPalette.subdued)
        }
        .foregroundStyle(MemoryPalette.text)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoryPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black, lineWidth: 0.9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.title) 폴더, 사진 \(photos.count)장")
    }
}

private enum MemoryPhotoFolderAlert: Identifiable {
    case confirmDeletion(Int)
    case deletionFailed(String)

    var id: String {
        switch self {
        case let .confirmDeletion(count):
            "confirm-\(count)"
        case let .deletionFailed(message):
            "error-\(message)"
        }
    }
}

private struct MemoryPhotoFolderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: MemoryPhotoFolder
    let photos: [MemoryPhoto]

    @State private var selectedPhoto: MemoryPhoto?
    @State private var selectionModeIsActive = false
    @State private var selectedPhotoIDs: Set<UUID> = []
    @State private var activeAlert: MemoryPhotoFolderAlert?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            MemoryPalette.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(MemoryPalette.paper, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(folder.title) 폴더 닫기")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))

                        Text("사진 \(photos.count)장")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(MemoryPalette.subdued)
                    }

                    Spacer()

                    if !photos.isEmpty {
                        Button(selectionModeIsActive ? "완료" : "선택") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectionModeIsActive.toggle()
                                if !selectionModeIsActive {
                                    selectedPhotoIDs.removeAll()
                                }
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(MemoryPalette.text)
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                        .background(MemoryPalette.paper, in: Capsule())
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            selectionModeIsActive
                                ? "사진 선택을 종료합니다"
                                : "삭제할 사진을 선택할 수 있습니다"
                        )
                    }
                }
                .foregroundStyle(MemoryPalette.text)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if photos.isEmpty {
                    ContentUnavailableView(
                        "아직 촬영한 사진이 없습니다",
                        systemImage: "camera",
                        description: Text("Idea에서 사진을 선택한 뒤 카메라로 촬영해보세요.")
                    )
                    .foregroundStyle(MemoryPalette.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical) {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(photos) { photo in
                                let isSelected = selectedPhotoIDs.contains(photo.id)

                                Button {
                                    if selectionModeIsActive {
                                        toggleSelection(photo.id)
                                    } else {
                                        selectedPhoto = photo
                                    }
                                } label: {
                                    MemoryPhotoThumbnail(photo: photo)
                                        .overlay {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .stroke(.white, lineWidth: 3)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                            .fill(.black.opacity(0.13))
                                                    )
                                            }
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            if selectionModeIsActive {
                                                MemoryPhotoSelectionBadge(isSelected: isSelected)
                                                    .padding(6)
                                            }
                                        }
                                        .overlay(alignment: .bottomTrailing) {
                                            Text(photo.capturedAt, format: .dateTime.hour().minute())
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 3)
                                                .background(.black.opacity(0.48), in: Capsule())
                                                .padding(5)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    accessibilityLabel(for: photo, isSelected: isSelected)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectionModeIsActive {
                HStack(spacing: 12) {
                    Text("\(selectedPhotoIDs.count)장 선택")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MemoryPalette.text)

                    Spacer()

                    Button {
                        activeAlert = .confirmDeletion(selectedPhotoIDs.count)
                    } label: {
                        Label("삭제", systemImage: "trash.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(.red, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPhotoIDs.isEmpty)
                    .opacity(selectedPhotoIDs.isEmpty ? 0.42 : 1)
                    .accessibilityLabel("선택한 사진 삭제")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            MemoryPhotoFullscreenView(
                photos: photos,
                initialPhotoID: photo.id
            )
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case let .confirmDeletion(count):
                Alert(
                    title: Text("사진을 삭제할까요?"),
                    message: Text("선택한 사진 \(count)장이 Memory에서 영구적으로 삭제됩니다."),
                    primaryButton: .destructive(Text("삭제")) {
                        deleteSelectedPhotos()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            case let .deletionFailed(message):
                Alert(
                    title: Text("사진을 삭제하지 못했습니다"),
                    message: Text(message),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
        .onChange(of: photos.map(\.id)) { _, availablePhotoIDs in
            selectedPhotoIDs.formIntersection(availablePhotoIDs)
            if availablePhotoIDs.isEmpty {
                selectionModeIsActive = false
            }
        }
    }

    private func toggleSelection(_ photoID: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            if selectedPhotoIDs.contains(photoID) {
                selectedPhotoIDs.remove(photoID)
            } else {
                selectedPhotoIDs.insert(photoID)
            }
        }
    }

    private func accessibilityLabel(
        for photo: MemoryPhoto,
        isSelected: Bool
    ) -> String {
        let capturedAt = photo.capturedAt.formatted(date: .long, time: .shortened)
        if selectionModeIsActive {
            return "\(capturedAt)에 촬영한 사진, \(isSelected ? "선택됨" : "선택 안 됨")"
        }
        return "\(capturedAt)에 촬영한 사진 크게 보기"
    }

    private func deleteSelectedPhotos() {
        let photosToDelete = photos.filter { selectedPhotoIDs.contains($0.id) }
        guard !photosToDelete.isEmpty else { return }

        var stagedDeletions: [MemoryPhotoStorage.StagedDeletion] = []

        do {
            for photo in photosToDelete {
                do {
                    let deletion = try MemoryPhotoStorage.stagePhotoForDeletion(
                        id: photo.id,
                        originalRelativePath: photo.originalRelativePath,
                        thumbnailRelativePath: photo.thumbnailRelativePath
                    )
                    stagedDeletions.append(deletion)
                } catch MemoryPhotoStorageError.storedPhotoMissing {
                    // A broken record should still be removable from Memory.
                    continue
                } catch MemoryPhotoStorageError.invalidStoredPath {
                    continue
                }
            }
        } catch {
            for deletion in stagedDeletions.reversed() {
                try? MemoryPhotoStorage.rollbackDeletion(deletion)
            }
            activeAlert = .deletionFailed(error.localizedDescription)
            return
        }

        for photo in photosToDelete {
            modelContext.delete(photo)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            for deletion in stagedDeletions.reversed() {
                try? MemoryPhotoStorage.rollbackDeletion(deletion)
            }
            activeAlert = .deletionFailed(error.localizedDescription)
            return
        }

        for deletion in stagedDeletions {
            try? MemoryPhotoStorage.finishDeletion(deletion)
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            selectedPhotoIDs.removeAll()
            if photosToDelete.count == photos.count {
                selectionModeIsActive = false
            }
        }
    }
}

private struct MemoryPhotoSelectionBadge: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.red : .black.opacity(0.30))

            Circle()
                .stroke(.white, lineWidth: 2)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        .accessibilityHidden(true)
    }
}

private struct MemoryPhotoThumbnail: View {
    let photo: MemoryPhoto

    var body: some View {
        ZStack {
            MemoryPalette.scrapbook

            if let image = photo.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    MemoryCheckerboard(squareSize: 10)
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MemoryPalette.subdued)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .clipped()
    }
}

private struct MemoryPhotoFullscreenView: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [MemoryPhoto]

    @State private var selectedPhotoID: UUID

    init(photos: [MemoryPhoto], initialPhotoID: UUID) {
        self.photos = photos
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    private var selectedPhoto: MemoryPhoto? {
        photos.first { $0.id == selectedPhotoID }
    }

    private var selectedIndex: Int {
        photos.firstIndex { $0.id == selectedPhotoID } ?? 0
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $selectedPhotoID) {
                ForEach(photos) { photo in
                    MemoryPhotoFullscreenPage(photo: photo)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.54), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("사진 크게 보기 닫기")

                    Spacer()
                }

                Spacer()

                if let selectedPhoto {
                    HStack(spacing: 10) {
                        Text(selectedPhoto.capturedAt.formatted(date: .long, time: .shortened))

                        Text("\(selectedIndex + 1) / \(photos.count)")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.54), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .statusBarHidden()
    }
}

private struct MemoryPhotoFullscreenPage: View {
    let photo: MemoryPhoto

    var body: some View {
        Group {
            if let image = photo.originalImage ?? photo.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "사진을 불러올 수 없습니다",
                    systemImage: "photo.badge.exclamationmark"
                )
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

private enum ThreadCardStyle {
    case film
    case scrapbook
}

private struct ThreadCard: View {
    let style: ThreadCardStyle
    let tape: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            VStack(alignment: .leading, spacing: 3) {
                Group {
                    switch style {
                    case .film:
                        FilmStripPlaceholder()
                    case .scrapbook:
                        ScrapbookPlaceholder(showTape: tape)
                    }
                }
                .frame(height: size.height * 0.68)

                Text(style == .film ? "Film" : "Scrapbook")
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(MemoryPalette.navigation, in: Capsule())

                Text("Thread's Title")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(MemoryPalette.text)

                Text("2025 · Jul 15th, 2026")
                    .font(.system(size: 6.5, weight: .medium, design: .rounded))
                    .foregroundStyle(MemoryPalette.subdued)
            }
            .padding(7)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(MemoryPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.black, lineWidth: 0.9)
            }
        }
        .aspectRatio(0.82, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thread's Title")
    }
}

private struct FilmStripPlaceholder: View {
    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 4
            let cellWidth = (proxy.size.width - gap * 3) / 4
            let cellHeight = (proxy.size.height - gap * 2) / 3

            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: gap) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(.black, lineWidth: 0.8)
                                }
                                .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(MemoryPalette.scrapbook)
        .overlay { Rectangle().stroke(.black, lineWidth: 0.8) }
    }
}

private struct ScrapbookPlaceholder: View {
    let showTape: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(MemoryPalette.scrapbook)
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black, lineWidth: 0.8) }
                    .frame(width: proxy.size.width * 0.62, height: proxy.size.height * 0.78)
                    .offset(x: proxy.size.width * 0.16, y: proxy.size.height * 0.08)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.78, green: 0.78, blue: 0.77))
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black, lineWidth: 0.8) }
                    .frame(width: proxy.size.width * 0.56, height: proxy.size.height * 0.74)
                    .offset(x: -proxy.size.width * 0.15, y: -proxy.size.height * 0.06)

                if showTape {
                    Rectangle()
                        .fill(Color(red: 0.85, green: 0.84, blue: 0.81).opacity(0.90))
                        .frame(width: proxy.size.width * 0.42, height: 15)
                        .rotationEffect(.degrees(-9))
                        .offset(x: -proxy.size.width * 0.23, y: -proxy.size.height * 0.39)
                }
            }
        }
    }
}

private struct MonthsMemoryView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                MemoryPullHandle()
                    .frame(height: 33)

                MonthSection(title: "May 2026", layout: .may)
                MonthSection(title: "June 2026", layout: .june)
                MonthSection(title: "July 2026", layout: .july)
            }
            .padding(.horizontal, 38)
            .padding(.bottom, 92)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MemoryPullHandle: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(MemoryPalette.paper.opacity(0.55))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.black.opacity(0.14))
                        .frame(height: 0.7)
                }

            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MemoryPalette.text)
                .padding(.top, 3)
        }
    }
}

private enum MonthLayout {
    case may
    case june
    case july
}

private struct MonthSection: View {
    let title: String
    let layout: MonthLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MemoryPalette.text)

            MonthMosaic(layout: layout)
                .frame(height: layout == .june ? 170 : 142)
        }
    }
}

private struct MonthMosaic: View {
    let layout: MonthLayout

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let gap: CGFloat = 7

            switch layout {
            case .may:
                monthBlock("W1", width: w * 0.54, height: h, square: 11)
                    .position(x: w * 0.27, y: h / 2)
                monthBlock("W2", width: w * 0.46 - gap, height: h * 0.48, square: 10)
                    .position(x: w * 0.77 + gap / 2, y: h * 0.24)
                monthBlock("W3", width: w * 0.22, height: h * 0.48 - gap, square: 8)
                    .position(x: w * 0.66, y: h * 0.76 + gap / 2)
                monthBlock("W4", width: w * 0.24 - gap, height: h * 0.48 - gap, square: 9)
                    .position(x: w * 0.88, y: h * 0.76 + gap / 2)

            case .june:
                monthBlock("W1", width: w * 0.54, height: h, square: 12)
                    .position(x: w * 0.27, y: h / 2)
                monthBlock("W2", width: w * 0.46 - gap, height: h * 0.63, square: 10)
                    .position(x: w * 0.77 + gap / 2, y: h * 0.315)
                monthBlock("W3", width: w * 0.22, height: h * 0.37 - gap, square: 8)
                    .position(x: w * 0.66, y: h * 0.815 + gap / 2)
                monthBlock("W4", width: w * 0.24 - gap, height: h * 0.37 - gap, square: 9)
                    .position(x: w * 0.88, y: h * 0.815 + gap / 2)

            case .july:
                monthBlock("W1", width: w * 0.29, height: h * 0.48, square: 10)
                    .position(x: w * 0.145, y: h * 0.24)
                monthBlock("W2", width: w * 0.29, height: h * 0.48 - gap, square: 9)
                    .position(x: w * 0.145, y: h * 0.76 + gap / 2)
                monthBlock("W3", width: w * 0.71 - gap, height: h, square: 12)
                    .position(x: w * 0.645 + gap / 2, y: h / 2)
            }
        }
    }

    private func monthBlock(_ week: String, width: CGFloat, height: CGFloat, square: CGFloat) -> some View {
        let isCompact = width < 90 || height < 75
        return MemoryPhotoBlock(
            squareSize: square,
            heading: week,
            detail: isCompact ? "#ipsum" : "#lorem\n#ipsum\nlorem ipsum dolor sit amet"
        )
            .frame(width: width, height: height)
    }
}

private struct DaysMemoryView: View {
    var body: some View {
        VStack(spacing: 10) {
            MonthNavigationHeader()

            ScrollView(.vertical) {
                DayGrid()
                    .frame(height: 650)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 12)
    }
}

private struct MonthNavigationHeader: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 14) {
                Text("May 2026")
                    .foregroundStyle(MemoryPalette.subdued.opacity(0.65))
                Image(systemName: "chevron.left")
                Text("June 2026")
                    .fontWeight(.bold)
                Image(systemName: "chevron.right")
                Text("July 2026")
                    .foregroundStyle(MemoryPalette.subdued.opacity(0.65))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(MemoryPalette.text)

            HStack(spacing: 0) {
                ForEach(1...4, id: \.self) { week in
                    Text("W\(week)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .frame(width: 40, height: 20)
                        .background {
                            if week == 4 {
                                Capsule().fill(.white)
                            }
                        }
                }
            }
            .foregroundStyle(MemoryPalette.text)
            .padding(2)
            .background(MemoryPalette.navigation, in: Capsule())
        }
    }
}

private struct DayGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let gap: CGFloat = 7

            DayCard(day: "21st", weekday: "SUN", square: 13)
                .frame(width: w * 0.62, height: 190)
                .position(x: w * 0.31, y: 95)

            DayCard(day: "22nd", weekday: "MON", square: 12)
                .frame(width: w * 0.38 - gap, height: 120)
                .position(x: w * 0.81 + gap / 2, y: 60)

            DayCard(day: "23rd", weekday: "THU", square: 9)
                .frame(width: w * 0.38 - gap, height: 63)
                .position(x: w * 0.81 + gap / 2, y: 155 + gap / 2)

            DayCard(day: "24th", weekday: "WED", square: 13)
                .frame(width: w * 0.40, height: 155)
                .position(x: w * 0.20, y: 190 + gap + 77.5)

            DayCard(day: "25th", weekday: "THU", square: 13)
                .frame(width: w * 0.60 - gap, height: 155)
                .position(x: w * 0.70 + gap / 2, y: 190 + gap + 77.5)

            DayCard(day: "26th", weekday: "FRI", square: 12)
                .frame(width: w * 0.62, height: 145)
                .position(x: w * 0.31, y: 190 + 155 + gap * 2 + 72.5)

            DayCard(day: "27th", weekday: "SAT", square: 11)
                .frame(width: w * 0.38 - gap, height: 145)
                .position(x: w * 0.81 + gap / 2, y: 190 + 155 + gap * 2 + 72.5)
        }
    }
}

private struct DayCard: View {
    let day: String
    let weekday: String
    let square: CGFloat

    var body: some View {
        MemoryPhotoBlock(
            squareSize: square,
            heading: "\(day)\n\(weekday)",
            detail: "#lorem\n#ipsum\nlorem ipsum dolor sit amet"
        )
    }
}

private struct MomentsMemoryView: View {
    var body: some View {
        VStack(spacing: 8) {
            WeekNavigationHeader()

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 8) {
                    TimelineLabels()
                        .frame(width: 50, height: 640)

                    MomentsGrid()
                        .frame(height: 640)
                }
                .padding(.horizontal, 29)
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 10)
    }
}

private struct WeekNavigationHeader: View {
    private let days = ["21st\nSUN", "22nd\nMON", "23rd\nTUE", "24th\nWED", "25th\nTHU", "26th\nFRI", "27th\nSAT"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Text("Jun · W3")
                    .foregroundStyle(MemoryPalette.subdued)
                Image(systemName: "chevron.left")
                VStack(spacing: 0) {
                    Text("2026").font(.system(size: 7, weight: .bold))
                    Text("Jun · W4").fontWeight(.bold)
                }
                Image(systemName: "chevron.right")
                Text("Jul · W1")
                    .foregroundStyle(MemoryPalette.subdued)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(MemoryPalette.text)

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 6.5, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 34, height: 27)
                        .background {
                            if index == 0 {
                                Capsule().fill(.white)
                            }
                        }
                }
            }
            .foregroundStyle(MemoryPalette.text)
            .padding(2)
            .background(MemoryPalette.navigation, in: Capsule())
        }
    }
}

private struct TimelineLabels: View {
    private let labels = ["8 AM", "10 AM", "12 PM", "2 PM", "4 PM", "6 PM", "8 PM"]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: proxy.size.width - 5, y: 7))
                path.addLine(to: CGPoint(x: proxy.size.width - 5, y: proxy.size.height - 7))
            }
            .stroke(MemoryPalette.subdued.opacity(0.35), lineWidth: 1)

            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 3) {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                    Circle()
                        .fill(MemoryPalette.text)
                        .frame(width: 4, height: 4)
                }
                .foregroundStyle(MemoryPalette.text)
                .position(x: proxy.size.width / 2, y: CGFloat(index) * 100 + 8)
            }
        }
    }
}

private struct MomentsGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let gap: CGFloat = 7
            let half = (w - gap) / 2

            moment("8:10 AM", x: half / 2, y: 57, width: half, height: 114, square: 11)
            moment("10:39 AM", x: half + gap + half / 2, y: 57, width: half, height: 114, square: 12)

            moment("11:20 AM", x: w * 0.18, y: 177, width: w * 0.36, height: 112, square: 10)
            moment("1:12 PM", x: w * 0.68, y: 177, width: w * 0.64 - gap, height: 112, square: 11)

            moment("2:30 PM", x: w * 0.25, y: 283, width: w * 0.50 - gap / 2, height: 92, square: 10)
            moment("3:33 PM", x: w * 0.75, y: 283, width: w * 0.50 - gap / 2, height: 92, square: 10)

            moment("2:30 PM", x: w * 0.31, y: 382, width: w * 0.62 - gap / 2, height: 96, square: 11)
            moment("5:29 PM", x: w * 0.81, y: 382, width: w * 0.38 - gap / 2, height: 96, square: 9)

            moment("6:10 PM", x: w * 0.25, y: 476, width: w * 0.50 - gap / 2, height: 84, square: 10)
            moment("7:59 PM", x: w * 0.75, y: 476, width: w * 0.50 - gap / 2, height: 84, square: 10)
        }
    }

    private func moment(
        _ time: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        square: CGFloat
    ) -> some View {
        MemoryPhotoBlock(squareSize: square, heading: time, detail: "#lorem\n#ipsum")
            .frame(width: width, height: height)
            .position(x: x, y: y)
    }
}

private struct MemoryPhotoBlock: View {
    let squareSize: CGFloat
    let heading: String
    let detail: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            MemoryCheckerboard(squareSize: squareSize)

            Text(heading)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(MemoryPalette.text)
                .padding(.top, 7)
                .padding(.leading, 8)

            Text(detail)
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundStyle(MemoryPalette.text)
                .padding(.leading, 8)
                .padding(.bottom, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black, lineWidth: 0.9)
        }
    }
}

private struct MemoryCheckerboard: View {
    let squareSize: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))

            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(Color.black.opacity(0.055)))
                }
            }
        }
    }
}
