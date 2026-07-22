//
//  ContentView.swift
//  joheulttaeda
//
//  Created by donghun park on 7/20/26.
//

import SwiftUI
import AVFoundation
import AVKit
import Combine
import ImageIO
import SwiftData
import UIKit

private enum IdeaFolderOpenMode {
    case preview
    case album
}

private struct IdeaFolderPresentation: Identifiable {
    let id = UUID()
    let folder: IdeaFolder
    let openMode: IdeaFolderOpenMode
}

struct ContentView: View {
    @State private var selectedTab: HomeTab = .home
    @State private var folderPresentation: IdeaFolderPresentation?
    @State private var selectedIdeaPhotoIDs: Set<String> = []
    @Namespace private var ideaTransitionNamespace

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let isCompact = height < 720
            let lineY: CGFloat = isCompact ? 100 : 116
            let cardWidth = min(width * 0.60, isCompact ? 210 : 238)
            let cardHeight: CGFloat = isCompact ? 304 : 344
            let stackHeight: CGFloat = isCompact ? 214 : 260

            ZStack(alignment: .topLeading) {
                DesignColor.background
                    .ignoresSafeArea()

                if selectedTab == .idea {
                    IdeaFeedView(
                        transitionNamespace: ideaTransitionNamespace,
                        selectedPhotoIDs: $selectedIdeaPhotoIDs
                    ) { folder, openMode in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            folderPresentation = IdeaFolderPresentation(
                                folder: folder,
                                openMode: openMode
                            )
                        }
                    }
                        .frame(width: width, height: height)
                } else if selectedTab == .memory {
                    MemorySectionView {
                        withAnimation(.smooth(duration: 0.58, extraBounce: 0)) {
                            selectedTab = .home
                        }
                    }
                    .frame(width: width, height: height)
                    .transition(.move(edge: .top))
                } else {
                    Clothesline()
                        .stroke(
                            DesignColor.rope,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: width, height: lineY + 28)

                    HeaderView {
                        withAnimation(.smooth(duration: 0.62, extraBounce: 0)) {
                            selectedTab = .memory
                        }
                    }
                        .frame(width: width, height: lineY)

                    HangingMemoryCard()
                        .frame(width: cardWidth, height: cardHeight)
                        .rotationEffect(.degrees(5.2))
                        .position(
                            x: width / 2,
                            y: lineY + 30 + (cardHeight / 2)
                        )

                    PinAndClip()
                        .frame(width: 34, height: 72)
                        .position(x: width / 2, y: lineY + 22)

                    IdeaStackView(
                        transitionNamespace: ideaTransitionNamespace,
                        onSwipeUp: {
                            withAnimation(.smooth(duration: 0.58, extraBounce: 0)) {
                                selectedTab = .idea
                            }
                        }
                    )
                        .frame(width: width, height: stackHeight)
                        .position(
                            x: width / 2,
                            y: height - (stackHeight / 2) + (isCompact ? 6 : 12)
                        )
                }

                if folderPresentation == nil && selectedTab != .memory {
                    BottomNavigation(selectedTab: $selectedTab)
                        .padding(.leading, 20)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }

                if let folderPresentation {
                    ExpandedFolderView(
                        folder: folderPresentation.folder,
                        selectedPhotoIDs: $selectedIdeaPhotoIDs,
                        opensAlbumDirectly: folderPresentation.openMode == .album
                    ) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            self.folderPresentation = nil
                        }
                    }
                    .id(folderPresentation.id)
                    .frame(width: width, height: height)
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .background(DesignColor.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct IdeaFeedView: View {
    let transitionNamespace: Namespace.ID
    @Binding var selectedPhotoIDs: Set<String>
    let onFolderOpen: (IdeaFolder, IdeaFolderOpenMode) -> Void

    @Query(sort: \IdeaMediaItem.importedAt, order: .reverse)
    private var importedMedia: [IdeaMediaItem]
    @State private var ageFilter = "Age"
    @State private var seasonFilter = "Season"
    @State private var spotFilter = "Spot"
    @State private var chromeIsVisible = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let cardWidth = min(140, width * 0.335)
            let columnSpacing = width * 0.075

            ZStack(alignment: .bottom) {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            FeedFilterMenu(
                                title: ageFilter,
                                width: 64,
                                options: ["Age", "New", "Old"]
                            ) { ageFilter = $0 }

                            FeedFilterMenu(
                                title: seasonFilter,
                                width: 70,
                                options: ["Season", "Spring", "Summer", "Fall", "Winter"]
                            ) { seasonFilter = $0 }

                            FeedFilterMenu(
                                title: spotFilter,
                                width: 64,
                                options: ["Spot", "Home", "Travel", "Outside"]
                            ) { spotFilter = $0 }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, width * 0.115)
                        .padding(.top, 16)
                        .opacity(chromeIsVisible ? 1 : 0)
                        .offset(y: chromeIsVisible ? 0 : -5)

                        HStack(alignment: .top, spacing: columnSpacing) {
                            VStack(spacing: 24) {
                                folderButton(.inbox, width: cardWidth)

                                folderButton(.outing, width: cardWidth)

                                folderButton(.nap, width: cardWidth)

                                photoButton(
                                    IdeaPhotoLibrary.instrument,
                                    transitionElement: .photoOne,
                                    width: cardWidth,
                                    height: cardWidth
                                )

                                folderButton(.swimming, width: cardWidth)

                                photoButton(
                                    IdeaPhotoLibrary.event,
                                    transitionElement: .photoTwo,
                                    width: cardWidth,
                                    height: cardWidth * 1.58
                                )
                            }

                            VStack(spacing: 24) {
                                folderButton(.food, width: cardWidth)

                                folderButton(.walk, width: cardWidth)

                                photoButton(
                                    IdeaPhotoLibrary.exercise,
                                    transitionElement: .photoThree,
                                    width: cardWidth,
                                    height: cardWidth * 1.34
                                )

                                folderButton(.costume, width: cardWidth)

                                folderButton(.fashion, width: cardWidth)
                            }
                            .padding(.top, 25)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 18)
                        .padding(.bottom, 125)
                    }
                }
                .scrollIndicators(.hidden)

                LinearGradient(
                    colors: [.clear, DesignColor.background.opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 112)
                .opacity(chromeIsVisible ? 1 : 0)
                .allowsHitTesting(false)

                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignColor.text)
                    .padding(.bottom, 58)
                    .opacity(chromeIsVisible ? 1 : 0)
                    .accessibilityHidden(true)

                if !selectedPhotoIDs.isEmpty {
                    selectionSummary
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 10)
                        .padding(.trailing, 16)
                        .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
                        .zIndex(3)

                    CameraLauncherButton(
                        selectedPhotos: allSelectablePhotos
                            .filter { selectedPhotoIDs.contains($0.id) }
                            .map { IdeaPhotoThumbnailDescriptor(photo: $0) },
                        contextTitle: "Idea"
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 20)
                        .padding(.bottom, 70)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                        .zIndex(4)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.32).delay(0.14)) {
                chromeIsVisible = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("아이디어 피드")
        .sensoryFeedback(.selection, trigger: selectedPhotoIDs.count)
    }

    private var selectionSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))

            Text("\(selectedPhotoIDs.count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Button {
                withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                    selectedPhotoIDs.removeAll()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.88), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("사진 선택 모두 해제")
        }
        .foregroundStyle(DesignColor.darkText)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(DesignColor.navigation.opacity(0.96), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.black.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedPhotoIDs.count)장의 사진 선택됨")
    }

    private func folderButton(_ folder: IdeaFolder, width: CGFloat) -> some View {
        folderLabel(folder, width: width)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .gesture(folderGesture(for: folder))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("탭하면 앨범을 열고, 길게 누르면 폴더를 미리 봅니다")
            .accessibilityAction {
                onFolderOpen(folder, .album)
            }
            .accessibilityAction(named: "폴더 미리보기") {
                onFolderOpen(folder, .preview)
            }
    }

    private func folderGesture(
        for folder: IdeaFolder
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 24)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    onFolderOpen(folder, .preview)
                case .second:
                    onFolderOpen(folder, .album)
                }
            }
    }

    @ViewBuilder
    private func folderLabel(_ folder: IdeaFolder, width: CGFloat) -> some View {
        let folderPhotos = photos(for: folder)

        if let transitionElement = folder.transitionElement {
            FeedFolderCard(color: folder.color, title: folder.title, photos: folderPhotos)
                .frame(width: width, height: 126)
                .matchedGeometryEffect(
                    id: transitionElement,
                    in: transitionNamespace,
                    isSource: false
                )
        } else {
            FeedFolderCard(color: folder.color, title: folder.title, photos: folderPhotos)
                .frame(width: width, height: 126)
        }
    }

    private func photos(for folder: IdeaFolder) -> [IdeaPhoto] {
        folder.photos + importedMedia
            .filter { $0.folderID == folder.rawValue }
            .map { IdeaPhoto(mediaItem: $0) }
    }

    private var allSelectablePhotos: [IdeaPhoto] {
        IdeaPhotoLibrary.allPhotos(importedMedia: importedMedia)
    }

    private func photoButton(
        _ photo: IdeaPhoto,
        transitionElement: IdeaTransitionElement,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let isSelected = selectedPhotoIDs.contains(photo.id)

        return Button {
            withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                if isSelected {
                    selectedPhotoIDs.remove(photo.id)
                } else {
                    selectedPhotoIDs.insert(photo.id)
                }
            }
        } label: {
            IdeaPhotoCard(photo: photo, cornerRadius: 8)
                .frame(width: width, height: height)
                .matchedGeometryEffect(
                    id: transitionElement,
                    in: transitionNamespace,
                    isSource: false
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DesignColor.blue, lineWidth: 3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 27, height: 27)
                            .background(DesignColor.blue, in: Circle())
                            .overlay {
                                Circle().stroke(.white, lineWidth: 2)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isSelected ? 0.975 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.title)
        .accessibilityHint(isSelected ? "탭하여 선택을 해제합니다" : "탭하여 사진을 선택합니다")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum IdeaTransitionElement: Hashable {
    case yellowFolder
    case pinkFolder
    case blueFolder
    case photoOne
    case photoTwo
    case photoThree
    case photoFour
    case photoFive
}

private struct IdeaPhoto: Identifiable, Hashable {
    let id: String
    let fileName: String
    let title: String
    var mediaKind: IdeaMediaKind = .image
    var originalRelativePath: String? = nil
    var thumbnailRelativePath: String? = nil
    var sourceURLString: String? = nil

    var image: UIImage? {
        if let thumbnailRelativePath {
            return IdeaPhotoImageStore.shared.image(relativePath: thumbnailRelativePath)
        }
        return IdeaPhotoImageStore.shared.image(named: fileName)
    }

    var originalURL: URL? {
        originalRelativePath.flatMap { IdeaMediaStorage.url(forRelativePath: $0) }
    }

    var sourceURL: URL? {
        sourceURLString.flatMap(URL.init(string:))
    }

    var cardAspectRatio: CGFloat {
        guard let image, image.size.width > 0 else { return 1.2 }
        return min(1.58, max(0.88, image.size.height / image.size.width))
    }

    init(
        id: String,
        fileName: String,
        title: String,
        mediaKind: IdeaMediaKind = .image,
        originalRelativePath: String? = nil,
        thumbnailRelativePath: String? = nil,
        sourceURLString: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.title = title
        self.mediaKind = mediaKind
        self.originalRelativePath = originalRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.sourceURLString = sourceURLString
    }

    init(mediaItem: IdeaMediaItem) {
        self.init(
            id: mediaItem.id.uuidString,
            fileName: "",
            title: mediaItem.title,
            mediaKind: mediaItem.kind,
            originalRelativePath: mediaItem.originalRelativePath,
            thumbnailRelativePath: mediaItem.thumbnailRelativePath,
            sourceURLString: mediaItem.sourceURLString
        )
    }
}

private final class IdeaPhotoImageStore {
    static let shared = IdeaPhotoImageStore()

    private let cache = NSCache<NSString, UIImage>()

    func image(named fileName: String) -> UIImage? {
        if let cached = cache.object(forKey: fileName as NSString) {
            return cached
        }

        let resourceURL = Bundle.main.url(
            forResource: fileName,
            withExtension: nil,
            subdirectory: "IdeaPhotos"
        ) ?? Bundle.main.url(forResource: fileName, withExtension: nil)

        guard
            let resourceURL,
            let imageSource = CGImageSourceCreateWithURL(resourceURL as CFURL, nil),
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1_600
                ] as CFDictionary
            )
        else {
            return nil
        }

        let image = UIImage(cgImage: thumbnail)
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    func image(relativePath: String) -> UIImage? {
        let cacheKey = "stored:\(relativePath)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = IdeaMediaStorage.image(forRelativePath: relativePath) else {
            return nil
        }
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}

private enum IdeaPhotoLibrary {
    static let outing = makePhotos(prefix: "outing", count: 3, title: "나들이")
    static let nap = makePhotos(
        prefix: "nap",
        count: 2,
        title: "낮잠",
        extensions: [2: "jpeg"]
    )
    static let food = makePhotos(prefix: "food", count: 6, title: "먹방")
    static let walk = makePhotos(
        prefix: "walk",
        count: 5,
        title: "산책",
        extensions: [1: "jpeg", 3: "png"]
    )
    static let swimming = makePhotos(prefix: "swimming", count: 6, title: "수영")
    static let instrument = makePhotos(prefix: "instrument", count: 1, title: "악기")[0]
    static let event = makePhotos(prefix: "event", count: 1, title: "이벤트")[0]
    static let exercise = makePhotos(prefix: "exercise", count: 1, title: "체육")[0]
    static let costume = makePhotos(
        prefix: "costume",
        count: 7,
        title: "코스프레",
        extensions: [1: "jpeg", 7: "png"]
    )
    static let fashion = makePhotos(prefix: "fashion", count: 5, title: "패션")

    static let singlePhotos = [instrument, event, exercise]

    static let allPhotos = outing
        + nap
        + food
        + walk
        + swimming
        + singlePhotos
        + costume
        + fashion

    static func allPhotos(importedMedia: [IdeaMediaItem]) -> [IdeaPhoto] {
        allPhotos + importedMedia.map { IdeaPhoto(mediaItem: $0) }
    }

    private static func makePhotos(
        prefix: String,
        count: Int,
        title: String,
        extensions: [Int: String] = [:]
    ) -> [IdeaPhoto] {
        (1...count).map { index in
            let fileExtension = extensions[index, default: "jpg"]
            let fileName = "\(prefix)_\(index).\(fileExtension)"

            return IdeaPhoto(
                id: fileName,
                fileName: fileName,
                title: count == 1 ? title : "\(title) \(index)"
            )
        }
    }
}

private enum IdeaFolder: String, Identifiable {
    case inbox = "idea-inbox"
    case outing
    case nap
    case food
    case walk
    case swimming
    case costume
    case fashion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: "새 아이디어"
        case .outing: "나들이"
        case .nap: "낮잠"
        case .food: "먹방"
        case .walk: "산책"
        case .swimming: "수영"
        case .costume: "코스프레"
        case .fashion: "패션"
        }
    }

    var color: Color {
        switch self {
        case .inbox, .outing, .walk, .fashion:
            DesignColor.yellow
        case .nap, .costume:
            DesignColor.pink
        case .food, .swimming:
            DesignColor.blue
        }
    }

    var photos: [IdeaPhoto] {
        switch self {
        case .inbox: []
        case .outing: IdeaPhotoLibrary.outing
        case .nap: IdeaPhotoLibrary.nap
        case .food: IdeaPhotoLibrary.food
        case .walk: IdeaPhotoLibrary.walk
        case .swimming: IdeaPhotoLibrary.swimming
        case .costume: IdeaPhotoLibrary.costume
        case .fashion: IdeaPhotoLibrary.fashion
        }
    }

    var transitionElement: IdeaTransitionElement? {
        switch self {
        case .inbox: nil
        case .outing: .yellowFolder
        case .nap: .pinkFolder
        case .food: .blueFolder
        case .walk, .swimming, .costume, .fashion: nil
        }
    }
}

private struct ExpandedFolderView: View {
    let folder: IdeaFolder
    @Binding var selectedPhotoIDs: Set<String>
    let opensAlbumDirectly: Bool
    let onDismiss: () -> Void

    @Query(sort: \IdeaMediaItem.importedAt, order: .reverse)
    private var importedMedia: [IdeaMediaItem]
    @State private var photosAreExpanded = false
    @State private var albumIsPresented = false
    @State private var albumSwipeOffset: CGFloat = 0
    @State private var isFinishingAlbumSwipe = false
    @Namespace private var albumTransitionNamespace

    init(
        folder: IdeaFolder,
        selectedPhotoIDs: Binding<Set<String>>,
        opensAlbumDirectly: Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.folder = folder
        _selectedPhotoIDs = selectedPhotoIDs
        self.opensAlbumDirectly = opensAlbumDirectly
        self.onDismiss = onDismiss
        _photosAreExpanded = State(initialValue: opensAlbumDirectly)
        _albumIsPresented = State(initialValue: opensAlbumDirectly)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let photoWidth = min(166, size.width * 0.40)
            let albumPhotos = displayedPhotos.enumerated().map { index, photo in
                IdeaAlbumPhoto(id: index, photo: photo)
            }

            ZStack {
                DesignColor.background
                    .ignoresSafeArea()

                if albumIsPresented {
                    IdeaFolderAlbumView(
                        folder: folder,
                        photos: albumPhotos,
                        transitionNamespace: albumTransitionNamespace,
                        selectedPhotoIDs: $selectedPhotoIDs,
                        onBack: opensAlbumDirectly ? onDismiss : closeAlbum
                    )
                    .transition(.identity)
                } else {
                    ZStack {
                        backgroundFolder(color: DesignColor.pink, width: photoWidth * 1.10, height: 150)
                            .position(x: size.width * 0.31, y: size.height * 0.42)

                        backgroundFolder(color: DesignColor.blue, width: photoWidth * 1.04, height: 150)
                            .position(x: size.width * 0.72, y: size.height * 0.57)

                        backgroundFolder(color: DesignColor.yellow, width: photoWidth * 1.10, height: 145)
                            .position(x: size.width * 0.34, y: size.height * 0.76)

                        ForEach(albumPhotos) { photo in
                            let placement = IdeaAlbumPreviewPlacement.all[
                                photo.id % IdeaAlbumPreviewPlacement.all.count
                            ]

                            expandedPhoto(
                                photo,
                                width: photoWidth * placement.widthScale,
                                height: photoWidth * placement.heightScale,
                                angle: placement.angle,
                                x: size.width * placement.x,
                                y: size.height * placement.y,
                                canvasHeight: size.height
                            )
                        }

                        Button {
                            onDismiss()
                        } label: {
                            ExpandedFolderPocket(folder: folder)
                                .frame(width: size.width * 0.84, height: 170)
                        }
                        .buttonStyle(.plain)
                        .position(x: size.width / 2, y: size.height - 85)
                        .accessibilityHint("아이디어 피드로 돌아갑니다")
                    }
                    .offset(y: max(0, albumSwipeOffset) * 0.18)
                    .contentShape(Rectangle())
                    .simultaneousGesture(folderPreviewGesture)
                    .transition(.identity)
                }

                if albumIsPresented && !selectedPhotoIDs.isEmpty {
                    CameraLauncherButton(
                        selectedPhotos: allSelectablePhotos
                            .filter { selectedPhotoIDs.contains($0.id) }
                            .map { IdeaPhotoThumbnailDescriptor(photo: $0) },
                        contextTitle: "Idea"
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 20)
                        .padding(.bottom, 22)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                        .zIndex(100)
                }
            }
        }
        .onAppear {
            guard !opensAlbumDirectly else { return }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                photosAreExpanded = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(folder.title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAction(named: "앨범 열기", openAlbum)
        .accessibilityAction(.escape, onDismiss)
        .sensoryFeedback(.selection, trigger: selectedPhotoIDs.count)
    }

    private var displayedPhotos: [IdeaPhoto] {
        folder.photos + importedMedia
            .filter { $0.folderID == folder.rawValue }
            .map { IdeaPhoto(mediaItem: $0) }
    }

    private var allSelectablePhotos: [IdeaPhoto] {
        IdeaPhotoLibrary.allPhotos(importedMedia: importedMedia)
    }

    private func expandedPhoto(
        _ photo: IdeaAlbumPhoto,
        width: CGFloat,
        height: CGFloat,
        angle: Double,
        x: CGFloat,
        y: CGFloat,
        canvasHeight: CGFloat
    ) -> some View {
        let liftMultiplier = 0.22 + (CGFloat(photo.id) * 0.012)

        return IdeaPhotoCard(photo: photo.photo, cornerRadius: 9)
            .frame(width: width, height: height)
            .matchedGeometryEffect(
                id: photo.id,
                in: albumTransitionNamespace,
                isSource: true
            )
            .rotationEffect(.degrees(photosAreExpanded ? angle : 0))
            .scaleEffect(photosAreExpanded ? 1 : 0.72)
            .position(x: x, y: y)
            .offset(y: photosAreExpanded ? 0 : canvasHeight - y + 40)
            .offset(y: min(0, albumSwipeOffset) * liftMultiplier)
            .opacity(photosAreExpanded ? 1 : 0)
            .animation(
                .spring(response: 0.58, dampingFraction: 0.76)
                    .delay(Double(photo.id) * 0.035),
                value: photosAreExpanded
            )
    }

    private var folderPreviewGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard photosAreExpanded, !isFinishingAlbumSwipe else { return }
                albumSwipeOffset = min(100, max(-110, value.translation.height))
            }
            .onEnded { value in
                guard !isFinishingAlbumSwipe else { return }

                let movedUp = value.translation.height < -52
                let projectedUp = value.predictedEndTranslation.height < -88
                let movedDown = value.translation.height > 80
                let projectedDown = value.predictedEndTranslation.height > 130

                if movedUp || projectedUp {
                    openAlbum()
                } else if movedDown || projectedDown {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        albumSwipeOffset = 0
                    }
                }
            }
    }

    private func openAlbum() {
        guard !albumIsPresented, !isFinishingAlbumSwipe else { return }
        isFinishingAlbumSwipe = true

        let progress = min(1, max(0, -albumSwipeOffset / 110))
        let finishDuration = 0.08 + ((1 - progress) * 0.12)

        withAnimation(
            .smooth(duration: finishDuration, extraBounce: 0),
            completionCriteria: .logicallyComplete
        ) {
            albumSwipeOffset = -110
        } completion: {
            withAnimation(
                .smooth(duration: 0.64, extraBounce: 0),
                completionCriteria: .logicallyComplete
            ) {
                albumIsPresented = true
            } completion: {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    albumSwipeOffset = 0
                    isFinishingAlbumSwipe = false
                }
            }
        }
    }

    private func closeAlbum() {
        withAnimation(.smooth(duration: 0.58, extraBounce: 0)) {
            albumIsPresented = false
        }
    }

    private func backgroundFolder(color: Color, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(color.opacity(0.70))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.black.opacity(0.55), lineWidth: 0.9)
            }
            .frame(width: width, height: height)
    }
}

private struct IdeaAlbumPhoto: Identifiable {
    let id: Int
    let photo: IdeaPhoto

    var albumAspectRatio: CGFloat { photo.cardAspectRatio }
}

private struct IdeaAlbumPreviewPlacement {
    let widthScale: CGFloat
    let heightScale: CGFloat
    let angle: Double
    let x: CGFloat
    let y: CGFloat

    static let all = [
        IdeaAlbumPreviewPlacement(widthScale: 1.00, heightScale: 1.50, angle: 4, x: 0.36, y: 0.26),
        IdeaAlbumPreviewPlacement(widthScale: 1.00, heightScale: 1.47, angle: -4, x: 0.68, y: 0.27),
        IdeaAlbumPreviewPlacement(widthScale: 0.98, heightScale: 0.95, angle: 3, x: 0.36, y: 0.39),
        IdeaAlbumPreviewPlacement(widthScale: 0.98, heightScale: 0.98, angle: -7, x: 0.70, y: 0.43),
        IdeaAlbumPreviewPlacement(widthScale: 0.96, heightScale: 1.47, angle: -12, x: 0.35, y: 0.58),
        IdeaAlbumPreviewPlacement(widthScale: 0.96, heightScale: 1.45, angle: 6, x: 0.69, y: 0.61),
        IdeaAlbumPreviewPlacement(widthScale: 0.94, heightScale: 1.03, angle: -3, x: 0.35, y: 0.79),
        IdeaAlbumPreviewPlacement(widthScale: 0.92, heightScale: 1.02, angle: 17, x: 0.68, y: 0.80)
    ]
}

private struct IdeaFolderAlbumView: View {
    let folder: IdeaFolder
    let photos: [IdeaAlbumPhoto]
    let transitionNamespace: Namespace.ID
    @Binding var selectedPhotoIDs: Set<String>
    let onBack: () -> Void

    @State private var chromeIsVisible = false
    @State private var selectionModeIsActive = false
    @State private var previewedPhoto: IdeaPhoto?
    @State private var previewedMedia: IdeaPhoto?

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = (proxy.size.width - 54) / 2

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    albumHeader

                    HStack(alignment: .top, spacing: 14) {
                        albumColumn(
                            photos.filter { $0.id.isMultiple(of: 2) },
                            width: columnWidth
                        )

                        albumColumn(
                            photos.filter { !$0.id.isMultiple(of: 2) },
                            width: columnWidth
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 54)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.28).delay(0.16)) {
                chromeIsVisible = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(folder.title.replacingOccurrences(of: "\n", with: " ")) 앨범")
        .fullScreenCover(item: $previewedPhoto) { photo in
            IdeaPhotoFullscreenView(photo: photo)
        }
        .sheet(item: $previewedMedia) { photo in
            switch photo.mediaKind {
            case .video:
                if let videoURL = photo.originalURL {
                    IdeaVideoPlayerView(title: photo.title, videoURL: videoURL)
                }
            case .link:
                if let sourceURL = photo.sourceURL {
                    InstagramEmbedPlayerView(title: photo.title, sourceURL: sourceURL)
                }
            case .image:
                EmptyView()
            }
        }
    }

    private var albumHeader: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignColor.text)
                    .frame(width: 40, height: 40)
                    .background(DesignColor.navigation, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("폴더 미리보기로 돌아가기")

            VStack(alignment: .leading, spacing: 4) {
                Text("Album")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignColor.text)

                Text(folder.title.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignColor.darkText)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(folder.color.opacity(0.86), in: Capsule())
            }

            Spacer(minLength: 0)

            selectionControls
        }
        .opacity(chromeIsVisible ? 1 : 0)
        .offset(y: chromeIsVisible ? 0 : -6)
    }

    private var selectionControls: some View {
        HStack(spacing: 7) {
            if !selectedPhotoIDs.isEmpty {
                CompactPhotoSelectionSummary(
                    count: selectedPhotoIDs.count,
                    onClear: clearSelection
                )
                .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
            } else if selectionModeIsActive {
                Text("사진을 탭하세요")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignColor.text.opacity(0.82))
                    .transition(.opacity)
            } else {
                Text("\(photos.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignColor.text.opacity(0.78))
            }

            Button {
                withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                    selectionModeIsActive.toggle()
                }
            } label: {
                Text(selectionModeIsActive ? "완료" : "선택")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(selectionModeIsActive ? .white : DesignColor.darkText)
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .background(
                        selectionModeIsActive ? DesignColor.blue : DesignColor.navigation,
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(.black.opacity(selectionModeIsActive ? 0.08 : 0.16), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectionModeIsActive ? "사진 선택 완료" : "사진 선택 모드 시작")
        }
    }

    private func albumColumn(_ columnPhotos: [IdeaAlbumPhoto], width: CGFloat) -> some View {
        VStack(spacing: 16) {
            ForEach(columnPhotos) { photo in
                let isSelected = selectedPhotoIDs.contains(photo.photo.id)

                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        handleTap(photo)
                    } label: {
                        IdeaPhotoCard(photo: photo.photo, cornerRadius: 9)
                            .frame(width: width, height: width * photo.albumAspectRatio)
                            .matchedGeometryEffect(
                                id: photo.id,
                                in: transitionNamespace,
                                isSource: false
                            )
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(DesignColor.blue, lineWidth: 3)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if photo.photo.mediaKind != .video && selectionModeIsActive {
                                    PhotoSelectionModeBadge(isSelected: isSelected)
                                        .padding(8)
                                        .transition(.scale.combined(with: .opacity))
                                } else if isSelected {
                                    PhotoSelectionBadge()
                                        .padding(8)
                                }
                            }
                            .scaleEffect(isSelected ? 0.975 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(photo.photo.title)
                    .accessibilityHint(accessibilityHint(for: photo, isSelected: isSelected))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])

                    Text(photo.photo.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignColor.text)
                        .opacity(chromeIsVisible ? 1 : 0)
                }
            }
        }
    }

    private func handleTap(_ photo: IdeaAlbumPhoto) {
        switch photo.photo.mediaKind {
        case .image:
            if selectionModeIsActive {
                toggleSelection(photo.photo.id)
            } else {
                previewedPhoto = photo.photo
            }
        case .video:
            previewedMedia = photo.photo
        case .link:
            if selectionModeIsActive {
                toggleSelection(photo.photo.id)
            } else {
                previewedMedia = photo.photo
            }
        }
    }

    private func accessibilityHint(for photo: IdeaAlbumPhoto, isSelected: Bool) -> String {
        switch photo.photo.mediaKind {
        case .image:
            if selectionModeIsActive {
                isSelected ? "탭하여 선택을 해제합니다" : "탭하여 사진을 선택합니다"
            } else {
                "탭하여 사진을 전체 화면으로 봅니다"
            }
        case .video:
            "탭하여 저장된 릴스를 재생합니다"
        case .link:
            if selectionModeIsActive {
                isSelected ? "탭하여 선택을 해제합니다" : "탭하여 Instagram 링크를 선택합니다"
            } else {
                "탭하여 앱 안에서 Instagram 게시물을 엽니다"
            }
        }
    }

    private func toggleSelection(_ id: String) {
        withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
            if selectedPhotoIDs.contains(id) {
                selectedPhotoIDs.remove(id)
            } else {
                selectedPhotoIDs.insert(id)
            }
        }
    }

    private func clearSelection() {
        withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
            selectedPhotoIDs.removeAll()
        }
    }
}

private struct IdeaPhotoFullscreenView: View {
    let photo: IdeaPhoto

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(photo.title)
            } else {
                ContentUnavailableView(
                    "사진을 표시할 수 없습니다",
                    systemImage: "photo.badge.exclamationmark"
                )
                .foregroundStyle(.white)
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.58), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("사진 닫기")
                }

                Spacer()

                Text(photo.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.58), in: Capsule())
            }
            .padding(.horizontal, 16)
            .safeAreaPadding(.vertical, 12)
        }
        .statusBarHidden(true)
    }
}

private struct IdeaVideoPlayerView: View {
    let title: String
    let videoURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(title: String, videoURL: URL) {
        self.title = title
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .background(.black)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
        }
    }
}

private struct PhotoSelectionBadge: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 27, height: 27)
            .background(DesignColor.blue, in: Circle())
            .overlay {
                Circle().stroke(.white, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            .accessibilityHidden(true)
    }
}

private struct PhotoSelectionModeBadge: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? DesignColor.blue : .black.opacity(0.26))
                .frame(width: 27, height: 27)

            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 27, height: 27)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
        .accessibilityHidden(true)
    }
}

private struct CompactPhotoSelectionSummary: View {
    let count: Int
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))

            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .frame(minWidth: 22)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.88), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("사진 선택 모두 해제")
        }
        .foregroundStyle(DesignColor.darkText)
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .fixedSize(horizontal: true, vertical: false)
        .background(DesignColor.navigation.opacity(0.96), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.black.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(count)장의 사진 선택됨")
    }
}

private struct IdeaPhotoThumbnailDescriptor: Identifiable {
    let photo: IdeaPhoto

    var id: String { photo.id }

    @MainActor
    func render() -> UIImage? {
        photo.image
    }
}

private enum CameraLaunchAlert: Identifiable {
    case cameraUnavailable
    case liveActivityUnavailable(String)

    var id: String {
        switch self {
        case .cameraUnavailable:
            "cameraUnavailable"
        case .liveActivityUnavailable:
            "liveActivityUnavailable"
        }
    }

    var title: String {
        switch self {
        case .cameraUnavailable:
            "카메라를 사용할 수 없습니다"
        case .liveActivityUnavailable:
            "Live Activity를 시작할 수 없습니다"
        }
    }

    var message: String {
        switch self {
        case .cameraUnavailable:
            "기기에 카메라가 있는지 확인하고 설정에서 카메라 접근 권한을 허용해주세요."
        case let .liveActivityUnavailable(message):
            message
        }
    }
}

private struct CameraPresentation: Identifiable {
    let id = UUID()
    let referenceImages: [UIImage]
    let selectedPhotoCount: Int
}

private struct CameraLauncherButton: View {
    let selectedPhotos: [IdeaPhotoThumbnailDescriptor]
    let contextTitle: String

    @State private var cameraPresentation: CameraPresentation?
    @State private var launchAlert: CameraLaunchAlert?

    var body: some View {
        Button(action: openCamera) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(DesignColor.darkText, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.92), lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("카메라 열기")
        .accessibilityHint("선택한 사진과 함께 사용할 새 사진을 촬영합니다")
        .fullScreenCover(item: $cameraPresentation) { presentation in
            CameraCaptureView(
                referenceImages: presentation.referenceImages,
                selectedPhotoCount: presentation.selectedPhotoCount,
                onCapture: {
                    Task {
                        await CameraLiveActivityManager.shared.finish()
                    }
                },
                onCancel: {
                    Task {
                        await CameraLiveActivityManager.shared.cancel()
                    }
                }
            )
        }
        .alert(item: $launchAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .cancel(Text("확인"))
            )
        }
    }

    private func openCamera() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            launchAlert = .cameraUnavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    presentCamera()
                } else {
                    launchAlert = .cameraUnavailable
                }
            }
        case .denied, .restricted:
            launchAlert = .cameraUnavailable
        @unknown default:
            launchAlert = .cameraUnavailable
        }
    }

    private func presentCamera() {
        Task {
            let selectedImages = selectedPhotos.compactMap { $0.render() }

            do {
                try await CameraLiveActivityManager.shared.start(
                    selectedImages: selectedImages,
                    selectedPhotoCount: selectedPhotos.count,
                    contextTitle: contextTitle
                )

                // Give the system enough time to render the compact Dynamic Island
                // presentation before the full-screen camera interface appears.
                try? await Task.sleep(for: .milliseconds(650))
                cameraPresentation = CameraPresentation(
                    referenceImages: selectedImages,
                    selectedPhotoCount: selectedPhotos.count
                )
            } catch {
                launchAlert = .liveActivityUnavailable(error.localizedDescription)
            }
        }
    }
}

@MainActor
private final class CameraSessionController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back
    @Published var errorMessage: String?

    var onPhotoCaptured: ((Data) -> Void)?

    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false

    func start() {
        if !isConfigured {
            configureSession()
        }

        guard isConfigured, !session.isRunning else { return }
        let session = session
        Task.detached(priority: .userInitiated) {
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        let session = session
        Task.detached(priority: .utility) {
            session.stopRunning()
        }
    }

    func capturePhoto() {
        guard isReady, !isCapturing else { return }

        isCapturing = true
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() {
        guard !isCapturing, let currentInput = videoInput else { return }

        let nextPosition: AVCaptureDevice.Position = cameraPosition == .back ? .front : .back
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition),
            let nextInput = try? AVCaptureDeviceInput(device: device)
        else {
            errorMessage = "전환할 카메라를 찾을 수 없습니다."
            return
        }

        session.beginConfiguration()
        session.removeInput(currentInput)

        if session.canAddInput(nextInput) {
            session.addInput(nextInput)
            videoInput = nextInput
            cameraPosition = nextPosition
        } else {
            session.addInput(currentInput)
            errorMessage = "카메라를 전환할 수 없습니다."
        }

        session.commitConfiguration()
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let photoData = error == nil ? photo.fileDataRepresentation() : nil
        let errorDescription = error?.localizedDescription

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isCapturing = false

            if let photoData {
                self.onPhotoCaptured?(photoData)
            } else {
                self.errorMessage = errorDescription ?? "사진을 촬영하지 못했습니다. 다시 시도해주세요."
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            errorMessage = "후면 카메라를 준비할 수 없습니다."
            return
        }

        session.addInput(input)
        videoInput = input

        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            videoInput = nil
            errorMessage = "사진 촬영 기능을 준비할 수 없습니다."
            return
        }

        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        isConfigured = true
        isReady = true
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

private struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var camera = CameraSessionController()
    @State private var referencePanelIsExpanded = false
    @State private var captureFlashOpacity = 0.0
    @State private var isFinishing = false

    let referenceImages: [UIImage]
    let selectedPhotoCount: Int
    let onCapture: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            Color.black.opacity(camera.isReady ? 0 : 0.72)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.54), .clear, .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                SelectedPhotoCameraOverlay(
                    images: referenceImages,
                    selectedPhotoCount: selectedPhotoCount,
                    isExpanded: $referencePanelIsExpanded
                )

                HStack {
                    cameraControlButton(systemName: "xmark", label: "카메라 닫기") {
                        cancelCamera()
                    }

                    Spacer()

                    cameraControlButton(systemName: "arrow.triangle.2.circlepath.camera", label: "카메라 전환") {
                        camera.switchCamera()
                    }
                    .disabled(camera.isCapturing)
                }

                Spacer()

                if !camera.isReady {
                    ProgressView("카메라 준비 중")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                }

                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 5)
                            .frame(width: 82, height: 82)

                        Circle()
                            .fill(.white)
                            .frame(width: 66, height: 66)

                        if camera.isCapturing {
                            ProgressView()
                                .tint(.black)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!camera.isReady || camera.isCapturing || isFinishing)
                .opacity(camera.isReady ? 1 : 0.55)
                .accessibilityLabel("사진 촬영")
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Color.white
                .opacity(captureFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .background(.black)
        .statusBarHidden()
        .onAppear {
            camera.onPhotoCaptured = completeCapture
            camera.start()
        }
        .onDisappear {
            camera.onPhotoCaptured = nil
            camera.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                camera.start()
            case .inactive, .background:
                // The capture session should not run in the background. The Live
                // Activity intentionally remains active until capture or cancel.
                camera.stop()
            @unknown default:
                break
            }
        }
        .alert(
            "카메라 오류",
            isPresented: Binding(
                get: { camera.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        camera.errorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                camera.errorMessage = nil
            }
        } message: {
            Text(camera.errorMessage ?? "카메라를 사용할 수 없습니다.")
        }
    }

    private func cameraControlButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.44), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func capturePhoto() {
        guard !isFinishing else { return }
        withAnimation(.linear(duration: 0.06)) {
            captureFlashOpacity = 0.5
        }
        camera.capturePhoto()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.linear(duration: 0.12)) {
                captureFlashOpacity = 0
            }
        }
    }

    private func completeCapture(photoData: Data) {
        guard !isFinishing else { return }
        isFinishing = true
        camera.stop()

        let recorded: RecordedMemoryPhoto

        do {
            recorded = try MemoryPhotoRecorder.record(
                photoData: photoData,
                modelContext: modelContext
            )
        } catch {
            isFinishing = false
            camera.errorMessage = "사진을 Memory에 저장하지 못했습니다. \(error.localizedDescription)"
            camera.start()
            return
        }

        Task { @MainActor in
            await MemoryPhotoAutoClassifier.classify(
                recorded: recorded,
                modelContext: modelContext
            )
        }

        onCapture()
        dismiss()
    }

    private func cancelCamera() {
        guard !isFinishing else { return }
        isFinishing = true
        camera.stop()
        onCancel()
        dismiss()
    }
}

private struct SelectedPhotoCameraOverlay: View {
    let images: [UIImage]
    let selectedPhotoCount: Int
    @Binding var isExpanded: Bool

    private var visibleImages: [UIImage] {
        Array(images.prefix(8))
    }

    private var compactImages: [UIImage] {
        images
    }

    private var compactThumbnailSize: CGFloat {
        switch compactImages.count {
        case 0, 1: 132
        case 2: 112
        case 3: 92
        default: 78
        }
    }

    private var expandedThumbnailHeight: CGFloat {
        switch visibleImages.count {
        case 0, 1: 184
        case 2: 152
        case 3, 4: 100
        default: 80
        }
    }

    private var columns: [GridItem] {
        let count = min(max(visibleImages.count, 1), 4)
        return Array(repeating: GridItem(.flexible(), spacing: 6), count: count)
    }

    var body: some View {
        Group {
            if isExpanded {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(visibleImages.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFill()
                            .frame(height: expandedThumbnailHeight)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(Array(compactImages.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFill()
                                .frame(width: compactThumbnailSize, height: compactThumbnailSize)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: compactThumbnailSize)
                .transition(.opacity)
            }
        }
        .padding(isExpanded ? 12 : 10)
        .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.30), radius: 18, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onLongPressGesture(minimumDuration: 0.35) {
            withAnimation(.smooth(duration: 0.32, extraBounce: 0)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("선택한 아이디어 사진 \(selectedPhotoCount)장")
        .accessibilityHint(isExpanded ? "길게 눌러 사진을 접습니다" : "길게 눌러 선택 사진을 펼칩니다")
        .accessibilityAction {
            withAnimation(.smooth(duration: 0.32, extraBounce: 0)) {
                isExpanded.toggle()
            }
        }
    }
}

private struct ExpandedPhotoCard: View {
    let squareSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            CheckerboardView(squareSize: squareSize)

            Text("Title")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .italic()
                .foregroundStyle(DesignColor.darkText)
                .padding(.top, 9)
                .padding(.leading, 11)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.black, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.025), radius: 1, y: 1)
        .accessibilityLabel("Title 사진")
    }
}

private struct ExpandedFolderPocket: View {
    let folder: IdeaFolder

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(folder.color)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.black, lineWidth: 1.1)
                }

            Text(folder.title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignColor.darkText)
                .padding(.horizontal, 22)
                .padding(.bottom, 21)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FeedFilterMenu: View {
    let title: String
    let width: CGFloat
    let options: [String]
    let onSelection: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelection(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(DesignColor.text)
            .frame(width: width, height: 22)
            .background(DesignColor.paper, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.black.opacity(0.72), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 필터")
    }
}

private struct FeedPhotoCard: View {
    let squareSize: CGFloat

    var body: some View {
        CheckerboardView(squareSize: squareSize)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.black, lineWidth: 1.0)
            }
            .accessibilityLabel("사진 카드")
    }
}

private struct IdeaPhotoCard: View {
    let photo: IdeaPhoto
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    CheckerboardView(squareSize: 10)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay {
                if photo.mediaKind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(
                            width: min(proxy.size.width, proxy.size.height) * 0.36,
                            height: min(proxy.size.width, proxy.size.height) * 0.36
                        )
                        .background(.black.opacity(0.58), in: Circle())
                        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if photo.mediaKind == .link {
                    Image(systemName: "link")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.1, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(
                            width: min(proxy.size.width, proxy.size.height) * 0.24,
                            height: min(proxy.size.width, proxy.size.height) * 0.24
                        )
                        .background(.black.opacity(0.64), in: Circle())
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .padding(8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.black, lineWidth: 1)
        }
        .background(DesignColor.paper)
        .accessibilityLabel(photo.title)
    }
}

private struct FeedFolderCard: View {
    let color: Color
    let title: String
    let photos: [IdeaPhoto]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(.black, lineWidth: 1)
                    }
                    .frame(width: size.width * 0.20, height: 59)
                    .position(x: size.width * 0.10, y: 61)

                if !photos.isEmpty {
                    miniMemo(photo: previewPhoto(at: 0), width: size.width * 0.52, height: 72)
                        .rotationEffect(.degrees(-4))
                        .position(x: size.width * 0.35, y: 40)

                    miniMemo(photo: previewPhoto(at: 1), width: size.width * 0.55, height: 78)
                        .rotationEffect(.degrees(10))
                        .position(x: size.width * 0.62, y: 36)

                    miniMemo(photo: previewPhoto(at: 2), width: size.width * 0.48, height: 70)
                        .rotationEffect(.degrees(1))
                        .position(x: size.width * 0.52, y: 48)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black.opacity(0.48))
                        .position(x: size.width / 2, y: 42)
                }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.black, lineWidth: 1.05)
                    }
                    .frame(height: 88)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .frame(width: size.width - 14)
                    .position(x: size.width / 2, y: size.height - 24)

                Text("\(photos.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.64))
                    .position(x: size.width - 13, y: size.height - 13)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
    }

    private func miniMemo(photo: IdeaPhoto, width: CGFloat, height: CGFloat) -> some View {
        IdeaPhotoCard(photo: photo, cornerRadius: 7)
            .frame(width: width, height: height)
    }

    private func previewPhoto(at index: Int) -> IdeaPhoto {
        photos[index % photos.count]
    }
}

private enum DesignColor {
    static let background = Color(red: 0.982, green: 0.959, blue: 0.945)
    static let paper = Color(red: 0.998, green: 0.995, blue: 0.991)
    static let text = Color(red: 0.48, green: 0.45, blue: 0.42)
    static let darkText = Color(red: 0.24, green: 0.22, blue: 0.20)
    static let rope = Color(red: 0.73, green: 0.59, blue: 0.45)
    static let pin = Color(red: 0.86, green: 0.72, blue: 0.55)
    static let navigation = Color(red: 0.91, green: 0.88, blue: 0.84)
    static let pink = Color(red: 0.96, green: 0.36, blue: 0.72)
    static let yellow = Color(red: 1.0, green: 0.75, blue: 0.10)
    static let blue = Color(red: 0.12, green: 0.62, blue: 0.91)
}

private struct HeaderView: View {
    let onSwipeDown: () -> Void

    @State private var pullOffset: CGFloat = 0
    @State private var isFinishingPull = false

    var body: some View {
        let pullProgress = min(1, max(0, pullOffset / 110))

        ZStack {
            VStack(spacing: 1) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))

                Text("Memory")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
            }
            .foregroundStyle(DesignColor.text)
            .frame(width: 190, height: 78)
            .scaleEffect(1 + (0.025 * pullProgress))
            .offset(y: 10 + (22 * pullProgress))
            .contentShape(Rectangle())
            .gesture(downwardSwipeGesture)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Memory")
            .accessibilityHint("아래로 쓸어내려 메모리 화면을 엽니다")
            .accessibilityAction(named: "메모리 화면 열기", onSwipeDown)

            ProfileButton()
                .frame(width: 42, height: 42)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 18)
        }
    }

    private var downwardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isFinishingPull else { return }
                pullOffset = min(110, max(0, value.translation.height))
            }
            .onEnded { value in
                guard !isFinishingPull else { return }

                let movedDown = value.translation.height > 48
                let projectedDown = value.predictedEndTranslation.height > 82

                if movedDown || projectedDown {
                    isFinishingPull = true

                    let progress = min(1, max(0, pullOffset / 110))
                    let finishDuration = 0.08 + ((1 - progress) * 0.12)

                    withAnimation(
                        .smooth(duration: finishDuration, extraBounce: 0),
                        completionCriteria: .logicallyComplete
                    ) {
                        pullOffset = 110
                    } completion: {
                        onSwipeDown()
                    }
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        pullOffset = 0
                    }
                }
            }
    }
}

private struct ProfileButton: View {
    var body: some View {
        Button(action: {}) {
            ZStack {
                Circle()
                    .fill(DesignColor.navigation.opacity(0.65))
                    .overlay {
                        Circle()
                            .stroke(.black, lineWidth: 1.1)
                    }

                Circle()
                    .stroke(.black, lineWidth: 1.1)
                    .frame(width: 11, height: 11)
                    .offset(y: -7)

                Path { path in
                    path.move(to: CGPoint(x: 8, y: 34))
                    path.addCurve(
                        to: CGPoint(x: 34, y: 34),
                        control1: CGPoint(x: 11, y: 22),
                        control2: CGPoint(x: 31, y: 22)
                    )
                }
                .stroke(.black, lineWidth: 1.1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필")
    }
}

private struct Clothesline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edgeY = rect.height - 25
        let middleY = rect.height - 2

        path.move(to: CGPoint(x: 0, y: edgeY))
        path.addLine(to: CGPoint(x: rect.midX, y: middleY))
        path.addLine(to: CGPoint(x: rect.maxX, y: edgeY))
        return path
    }
}

private struct HangingMemoryCard: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let inset = size.width * 0.075
            let photoHeight = size.height * 0.64

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignColor.paper)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.black, lineWidth: 1.15)
                    }

                CheckerboardView(squareSize: max(12, size.width / 13))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.black, lineWidth: 1.15)
                    }
                    .frame(height: photoHeight)
                    .padding(.horizontal, inset)
                    .padding(.top, inset)

                Text("Every moment\nworth remembering")
                    .font(.system(size: max(14, size.width * 0.070), weight: .bold, design: .rounded))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignColor.darkText)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .position(x: size.width / 2, y: size.height * 0.83)
            }
        }
        .shadow(color: .black.opacity(0.035), radius: 1, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("추억 사진 카드")
    }
}

private struct PinAndClip: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.gray.opacity(0.85), lineWidth: 1.4)
                .frame(width: 11, height: 38)
                .offset(y: 27)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.45, green: 0.35, blue: 0.25))
                .frame(width: 8, height: 13)
                .offset(y: 15)

            Circle()
                .fill(DesignColor.pin)
                .overlay {
                    Circle()
                        .stroke(.black, lineWidth: 1.1)
                }
                .frame(width: 23, height: 23)
        }
        .accessibilityHidden(true)
    }
}

private struct CheckerboardView: View {
    let squareSize: CGFloat

    var body: some View {
        Canvas { context, size in
            var checkerPath = Path()

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
                    checkerPath.addRect(rect)
                }
            }

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.fill(checkerPath, with: .color(Color.black.opacity(0.055)))
        }
    }
}

private struct IdeaStackView: View {
    let transitionNamespace: Namespace.ID
    let onSwipeUp: () -> Void

    @State private var swipeOffset: CGFloat = 0
    @State private var isFinishingSwipe = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let centerX = size.width / 2
            let scale = min(1, size.width / 390)
            let swipeProgress = min(1, max(0, -swipeOffset / 110))

            ZStack {
                ZStack {
                    memo(photo: IdeaPhotoLibrary.outing[0], width: 74, height: 116, square: 9)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoFour,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-12 + (7 * swipeProgress)))
                        .position(x: centerX - 103 * scale, y: 83)
                        .offset(x: -34 * swipeProgress, y: -46 * swipeProgress)

                    memo(photo: IdeaPhotoLibrary.nap[0], width: 79, height: 125, square: 9)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoFive,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-2 + (2 * swipeProgress)))
                        .position(x: centerX - 56 * scale, y: 52)
                        .offset(x: 34 * swipeProgress, y: -43 * swipeProgress)

                    memo(photo: IdeaPhotoLibrary.food[0], width: 82, height: 124, square: 10)
                        .rotationEffect(.degrees(4))
                        .position(x: centerX - 10 * scale, y: 58)

                    memo(photo: IdeaPhotoLibrary.walk[0], width: 83, height: 126, square: 10)
                        .rotationEffect(.degrees(14))
                        .position(x: centerX + 39 * scale, y: 43)

                    memo(photo: IdeaPhotoLibrary.swimming[0], width: 77, height: 120, square: 9)
                        .rotationEffect(.degrees(7))
                        .position(x: centerX + 107 * scale, y: 77)

                    folder(color: DesignColor.pink, width: 215, height: 125)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.pinkFolder,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-8 + (5 * swipeProgress)))
                        .position(x: centerX - 77 * scale, y: 117)
                        .offset(x: -22 * swipeProgress, y: -25 * swipeProgress)

                    folder(color: DesignColor.yellow, width: 246, height: 137)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.yellowFolder,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(2 - (2 * swipeProgress)))
                        .position(x: centerX, y: 103)
                        .offset(x: -14 * swipeProgress, y: -45 * swipeProgress)

                    memo(photo: IdeaPhotoLibrary.costume[0], width: 72, height: 113, square: 9)
                        .rotationEffect(.degrees(-1))
                        .position(x: centerX + 27 * scale, y: 96)

                    folder(color: DesignColor.blue, width: 216, height: 124)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.blueFolder,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(5 - (4 * swipeProgress)))
                        .position(x: centerX + 91 * scale, y: 128)
                        .offset(x: 24 * swipeProgress, y: -30 * swipeProgress)

                    memo(photo: IdeaPhotoLibrary.instrument, width: 156, height: 168, square: 12)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoOne,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-5 + (3 * swipeProgress)))
                        .position(x: centerX - 102 * scale, y: 191)
                        .offset(x: -22 * swipeProgress, y: -45 * swipeProgress)

                    memo(photo: IdeaPhotoLibrary.event, width: 150, height: 172, square: 13)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoTwo,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(3 - (2 * swipeProgress)))
                        .position(x: centerX - 2 * scale, y: 192)
                        .offset(x: 14 * swipeProgress, y: -57 * swipeProgress)

                    memo(photo: IdeaPhotoLibrary.exercise, width: 145, height: 158, square: 12)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoThree,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(5 - (3 * swipeProgress)))
                        .position(x: centerX + 102 * scale, y: 196)
                        .offset(x: 28 * swipeProgress, y: -39 * swipeProgress)
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(0.62, anchor: .bottom)

                LinearGradient(
                    colors: [.clear, DesignColor.background.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 88)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                VStack(spacing: 2) {
                    Text("Idea")
                        .font(.system(size: 25, weight: .bold, design: .rounded))

                    Image(systemName: "chevron.up")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(DesignColor.text)
                .position(x: centerX, y: size.height - 67)
                .opacity(1 - (0.72 * swipeProgress))
            }
            .scaleEffect(1 + (0.025 * swipeProgress), anchor: .bottom)
            .offset(y: max(-42, min(0, swipeOffset * 0.34)))
            .contentShape(Rectangle())
            .gesture(upwardSwipeGesture)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("아이디어 카드 모음")
        .accessibilityHint("위로 쓸어올려 아이디어 피드를 엽니다")
        .accessibilityAction(named: "아이디어 피드 열기", onSwipeUp)
    }

    private var upwardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isFinishingSwipe else { return }
                swipeOffset = max(-110, min(0, value.translation.height))
            }
            .onEnded { value in
                guard !isFinishingSwipe else { return }

                let movedUp = value.translation.height < -48
                let projectedUp = value.predictedEndTranslation.height < -82

                if movedUp || projectedUp {
                    isFinishingSwipe = true

                    let progress = min(1, max(0, -swipeOffset / 110))
                    let finishDuration = 0.08 + ((1 - progress) * 0.12)

                    withAnimation(
                        .smooth(duration: finishDuration, extraBounce: 0),
                        completionCriteria: .logicallyComplete
                    ) {
                        swipeOffset = -110
                    } completion: {
                        onSwipeUp()
                    }
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        swipeOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    private func memo(
        photo: IdeaPhoto? = nil,
        width: CGFloat,
        height: CGFloat,
        square: CGFloat
    ) -> some View {
        if let photo {
            IdeaPhotoCard(photo: photo, cornerRadius: 9)
                .frame(width: width, height: height)
        } else {
            CheckerboardView(squareSize: square)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.black, lineWidth: 1.05)
                }
                .frame(width: width, height: height)
        }
    }

    private func folder(color: Color, width: CGFloat, height: CGFloat) -> some View {
        FolderPocketShape()
            .fill(color)
            .overlay {
                FolderPocketShape()
                    .stroke(.black, lineWidth: 1.2)
            }
            .frame(width: width, height: height)
    }
}

private struct FolderPocketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 10
        let tabStart = rect.width * 0.28
        let tabEnd = rect.width * 0.54

        path.move(to: CGPoint(x: 0, y: 30))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: 20),
            control: CGPoint(x: 0, y: 20)
        )
        path.addLine(to: CGPoint(x: tabStart, y: 20))
        path.addLine(to: CGPoint(x: tabStart + 7, y: 7))
        path.addQuadCurve(
            to: CGPoint(x: tabStart + 15, y: 3),
            control: CGPoint(x: tabStart + 9, y: 3)
        )
        path.addLine(to: CGPoint(x: tabEnd, y: 3))
        path.addQuadCurve(
            to: CGPoint(x: tabEnd + 10, y: 12),
            control: CGPoint(x: tabEnd + 8, y: 3)
        )
        path.addLine(to: CGPoint(x: tabEnd + 15, y: 20))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: 20))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: 30),
            control: CGPoint(x: rect.maxX, y: 20)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - radius),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

private enum HomeTab: CaseIterable {
    case home
    case memory
    case idea
}

private struct BottomNavigation: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        HStack(spacing: 2) {
            tabButton(.home, title: nil, systemImage: "house.fill")
            tabButton(.memory, title: "Memory", systemImage: nil)
            tabButton(.idea, title: "Idea", systemImage: nil)
        }
        .padding(4)
        .background(DesignColor.navigation, in: Capsule())
        .fixedSize()
    }

    @ViewBuilder
    private func tabButton(_ tab: HomeTab, title: String?, systemImage: String?) -> some View {
        Button {
            let animation: Animation

            if tab == .idea || selectedTab == .idea {
                animation = .smooth(duration: 0.58, extraBounce: 0)
            } else if tab == .memory || selectedTab == .memory {
                animation = .smooth(duration: 0.58, extraBounce: 0)
            } else {
                animation = .easeInOut(duration: 0.18)
            }

            withAnimation(animation) {
                selectedTab = tab
            }
        } label: {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                } else if let title {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(selectedTab == tab ? DesignColor.text : DesignColor.text.opacity(0.92))
            .frame(width: tab == .home ? 44 : 58, height: 34)
            .background {
                if selectedTab == tab {
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.035), radius: 2, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title ?? "홈")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}

#Preview {
    ContentView()
}
