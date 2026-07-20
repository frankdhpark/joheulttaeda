//
//  ContentView.swift
//  joheulttaeda
//
//  Created by donghun park on 7/20/26.
//

import SwiftUI
import AVFoundation
import UIKit

struct ContentView: View {
    @State private var selectedTab: HomeTab = .home
    @State private var expandedFolder: IdeaFolder?
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
                    IdeaFeedView(transitionNamespace: ideaTransitionNamespace) { folder in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            expandedFolder = folder
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

                if expandedFolder == nil && selectedTab != .memory {
                    BottomNavigation(selectedTab: $selectedTab)
                        .padding(.leading, 20)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }

                if let expandedFolder {
                    ExpandedFolderView(folder: expandedFolder) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            self.expandedFolder = nil
                        }
                    }
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
    let onFolderTap: (IdeaFolder) -> Void

    @State private var ageFilter = "Age"
    @State private var seasonFilter = "Season"
    @State private var spotFilter = "Spot"
    @State private var chromeIsVisible = false
    @State private var selectedPhotos: Set<IdeaTransitionElement> = []

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
                                folderButton(.amusementPark, width: cardWidth)

                                folderButton(.cherryBlossom, width: cardWidth)

                                transitionPhoto(
                                    .photoOne,
                                    squareSize: 8,
                                    width: cardWidth,
                                    height: cardWidth * 0.82
                                )

                                transitionPhoto(
                                    .photoFour,
                                    squareSize: 13,
                                    width: cardWidth,
                                    height: cardWidth * 1.56
                                )

                                folderButton(.warmAfternoon, width: cardWidth)
                            }

                            VStack(spacing: 24) {
                                transitionPhoto(
                                    .photoTwo,
                                    squareSize: 14,
                                    width: cardWidth,
                                    height: cardWidth * 1.55
                                )

                                folderButton(.rainyDay, width: cardWidth)

                                transitionPhoto(
                                    .photoThree,
                                    squareSize: 13,
                                    width: cardWidth,
                                    height: cardWidth * 1.60
                                )

                                transitionPhoto(
                                    .photoFive,
                                    squareSize: 9,
                                    width: cardWidth,
                                    height: cardWidth * 0.86
                                )

                                folderButton(.littleMoments, width: cardWidth)
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

                if !selectedPhotos.isEmpty {
                    selectionSummary
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 10)
                        .padding(.trailing, 16)
                        .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
                        .zIndex(3)

                    CameraLauncherButton(
                        selectedPhotos: selectedPhotos
                            .sorted { $0.photoSortOrder < $1.photoSortOrder }
                            .compactMap(\.liveActivityDescriptor),
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
        .sensoryFeedback(.selection, trigger: selectedPhotos.count)
    }

    private var selectionSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))

            Text("\(selectedPhotos.count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Button {
                withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                    selectedPhotos.removeAll()
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
        .accessibilityLabel("\(selectedPhotos.count)장의 사진 선택됨")
    }

    private func folderButton(_ folder: IdeaFolder, width: CGFloat) -> some View {
        Button {
            onFolderTap(folder)
        } label: {
            folderLabel(folder, width: width)
        }
        .buttonStyle(.plain)
        .accessibilityHint("폴더의 사진을 펼칩니다")
    }

    @ViewBuilder
    private func folderLabel(_ folder: IdeaFolder, width: CGFloat) -> some View {
        if let transitionElement = folder.transitionElement {
            FeedFolderCard(color: folder.color, title: folder.title)
                .frame(width: width, height: 126)
                .matchedGeometryEffect(
                    id: transitionElement,
                    in: transitionNamespace,
                    isSource: false
                )
        } else {
            FeedFolderCard(color: folder.color, title: folder.title)
                .frame(width: width, height: 126)
        }
    }

    private func transitionPhoto(
        _ element: IdeaTransitionElement,
        squareSize: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let isSelected = selectedPhotos.contains(element)

        return Button {
            withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                if isSelected {
                    selectedPhotos.remove(element)
                } else {
                    selectedPhotos.insert(element)
                }
            }
        } label: {
            FeedPhotoCard(squareSize: squareSize)
                .frame(width: width, height: height)
                .matchedGeometryEffect(
                    id: element,
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
        .accessibilityLabel("아이디어 사진")
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

    var photoSortOrder: Int {
        switch self {
        case .photoOne: 0
        case .photoTwo: 1
        case .photoThree: 2
        case .photoFour: 3
        case .photoFive: 4
        case .yellowFolder: 5
        case .pinkFolder: 6
        case .blueFolder: 7
        }
    }

    var liveActivityDescriptor: IdeaPhotoThumbnailDescriptor? {
        switch self {
        case .photoOne:
            IdeaPhotoThumbnailDescriptor(id: "feed-photo-1", squareSize: 8, showsTitle: false)
        case .photoTwo:
            IdeaPhotoThumbnailDescriptor(id: "feed-photo-2", squareSize: 14, showsTitle: false)
        case .photoThree:
            IdeaPhotoThumbnailDescriptor(id: "feed-photo-3", squareSize: 13, showsTitle: false)
        case .photoFour:
            IdeaPhotoThumbnailDescriptor(id: "feed-photo-4", squareSize: 13, showsTitle: false)
        case .photoFive:
            IdeaPhotoThumbnailDescriptor(id: "feed-photo-5", squareSize: 9, showsTitle: false)
        case .yellowFolder, .pinkFolder, .blueFolder:
            nil
        }
    }
}

private enum IdeaFolder: String, Identifiable {
    case amusementPark
    case cherryBlossom
    case rainyDay
    case warmAfternoon
    case littleMoments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amusementPark:
            "Our Baby's First\nAmusement Park Trip"
        case .cherryBlossom:
            "Cherry Blossom\nOuting"
        case .rainyDay:
            "A Rainy Day Out\nwith Our Baby"
        case .warmAfternoon:
            "A Warm Afternoon\nTogether"
        case .littleMoments:
            "Little Moments\nWorth Keeping"
        }
    }

    var color: Color {
        switch self {
        case .amusementPark, .warmAfternoon:
            DesignColor.yellow
        case .cherryBlossom, .littleMoments:
            DesignColor.pink
        case .rainyDay:
            DesignColor.blue
        }
    }

    var transitionElement: IdeaTransitionElement? {
        switch self {
        case .amusementPark:
            .yellowFolder
        case .cherryBlossom:
            .pinkFolder
        case .rainyDay:
            .blueFolder
        case .warmAfternoon, .littleMoments:
            nil
        }
    }
}

private struct ExpandedFolderView: View {
    let folder: IdeaFolder
    let onDismiss: () -> Void

    @State private var photosAreExpanded = false
    @State private var albumIsPresented = false
    @State private var albumSwipeOffset: CGFloat = 0
    @State private var isFinishingAlbumSwipe = false
    @State private var selectedAlbumPhotos: Set<Int> = []
    @Namespace private var albumTransitionNamespace

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let photoWidth = min(166, size.width * 0.40)

            ZStack {
                DesignColor.background
                    .ignoresSafeArea()

                if albumIsPresented {
                    IdeaFolderAlbumView(
                        folder: folder,
                        photos: IdeaAlbumPhoto.all,
                        transitionNamespace: albumTransitionNamespace,
                        selectedPhotos: $selectedAlbumPhotos,
                        onBack: closeAlbum
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

                        expandedPhoto(
                            IdeaAlbumPhoto.all[0],
                            width: photoWidth,
                            height: photoWidth * 1.50,
                            angle: 4,
                            x: size.width * 0.36,
                            y: size.height * 0.26,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[1],
                            width: photoWidth,
                            height: photoWidth * 1.47,
                            angle: -4,
                            x: size.width * 0.68,
                            y: size.height * 0.27,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[2],
                            width: photoWidth * 0.98,
                            height: photoWidth * 0.95,
                            angle: 3,
                            x: size.width * 0.36,
                            y: size.height * 0.39,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[3],
                            width: photoWidth * 0.98,
                            height: photoWidth * 0.98,
                            angle: -7,
                            x: size.width * 0.70,
                            y: size.height * 0.43,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[4],
                            width: photoWidth * 0.96,
                            height: photoWidth * 1.47,
                            angle: -12,
                            x: size.width * 0.35,
                            y: size.height * 0.58,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[5],
                            width: photoWidth * 0.96,
                            height: photoWidth * 1.45,
                            angle: 6,
                            x: size.width * 0.69,
                            y: size.height * 0.61,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[6],
                            width: photoWidth * 0.94,
                            height: photoWidth * 1.03,
                            angle: -3,
                            x: size.width * 0.35,
                            y: size.height * 0.79,
                            canvasHeight: size.height
                        )

                        expandedPhoto(
                            IdeaAlbumPhoto.all[7],
                            width: photoWidth * 0.92,
                            height: photoWidth * 1.02,
                            angle: 17,
                            x: size.width * 0.68,
                            y: size.height * 0.80,
                            canvasHeight: size.height
                        )

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

                if albumIsPresented && !selectedAlbumPhotos.isEmpty {
                    CameraLauncherButton(
                        selectedPhotos: IdeaAlbumPhoto.all
                            .filter { selectedAlbumPhotos.contains($0.id) }
                            .map {
                                IdeaPhotoThumbnailDescriptor(
                                    id: "album-photo-\($0.id)",
                                    squareSize: $0.squareSize,
                                    showsTitle: true
                                )
                            },
                        contextTitle: folder.title.replacingOccurrences(of: "\n", with: " ")
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
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                photosAreExpanded = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(folder.title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAction(named: "앨범 열기", openAlbum)
        .accessibilityAction(.escape, onDismiss)
        .sensoryFeedback(.selection, trigger: selectedAlbumPhotos.count)
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

        return ExpandedPhotoCard(squareSize: photo.squareSize)
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
            selectedAlbumPhotos.removeAll()
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
    let squareSize: CGFloat
    let albumAspectRatio: CGFloat

    static let all: [IdeaAlbumPhoto] = [
        IdeaAlbumPhoto(id: 0, squareSize: 13, albumAspectRatio: 1.34),
        IdeaAlbumPhoto(id: 1, squareSize: 13, albumAspectRatio: 1.02),
        IdeaAlbumPhoto(id: 2, squareSize: 9, albumAspectRatio: 0.88),
        IdeaAlbumPhoto(id: 3, squareSize: 10, albumAspectRatio: 1.26),
        IdeaAlbumPhoto(id: 4, squareSize: 15, albumAspectRatio: 1.48),
        IdeaAlbumPhoto(id: 5, squareSize: 14, albumAspectRatio: 1.16),
        IdeaAlbumPhoto(id: 6, squareSize: 10, albumAspectRatio: 0.96),
        IdeaAlbumPhoto(id: 7, squareSize: 9, albumAspectRatio: 1.32)
    ]
}

private struct IdeaFolderAlbumView: View {
    let folder: IdeaFolder
    let photos: [IdeaAlbumPhoto]
    let transitionNamespace: Namespace.ID
    @Binding var selectedPhotos: Set<Int>
    let onBack: () -> Void

    @State private var chromeIsVisible = false

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

            if selectedPhotos.isEmpty {
                Text("\(photos.count) photos")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignColor.text.opacity(0.78))
            } else {
                CompactPhotoSelectionSummary(
                    count: selectedPhotos.count,
                    onClear: clearSelection
                )
                .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
            }
        }
        .opacity(chromeIsVisible ? 1 : 0)
        .offset(y: chromeIsVisible ? 0 : -6)
    }

    private func albumColumn(_ columnPhotos: [IdeaAlbumPhoto], width: CGFloat) -> some View {
        VStack(spacing: 16) {
            ForEach(columnPhotos) { photo in
                let isSelected = selectedPhotos.contains(photo.id)

                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        toggleSelection(photo.id)
                    } label: {
                        ExpandedPhotoCard(squareSize: photo.squareSize)
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
                                if isSelected {
                                    PhotoSelectionBadge()
                                        .padding(8)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .scaleEffect(isSelected ? 0.975 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Moment \(photo.id + 1)")
                    .accessibilityHint(isSelected ? "탭하여 선택을 해제합니다" : "탭하여 사진을 선택합니다")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])

                    Text("Moment \(photo.id + 1)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignColor.text)
                        .opacity(chromeIsVisible ? 1 : 0)
                }
            }
        }
    }

    private func toggleSelection(_ id: Int) {
        withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
            if selectedPhotos.contains(id) {
                selectedPhotos.remove(id)
            } else {
                selectedPhotos.insert(id)
            }
        }
    }

    private func clearSelection() {
        withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
            selectedPhotos.removeAll()
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

private struct CompactPhotoSelectionSummary: View {
    let count: Int
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))

            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))

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
        .accessibilityLabel("\(count)장의 사진 선택됨")
    }
}

private struct IdeaPhotoThumbnailDescriptor: Identifiable {
    let id: String
    let squareSize: CGFloat
    let showsTitle: Bool

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(
            content: thumbnailView
                .frame(width: 96, height: 96)
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if showsTitle {
            ExpandedPhotoCard(squareSize: squareSize)
        } else {
            FeedPhotoCard(squareSize: squareSize)
        }
    }
}

private struct CameraLauncherButton: View {
    let selectedPhotos: [IdeaPhotoThumbnailDescriptor]
    let contextTitle: String

    @State private var cameraIsPresented = false
    @State private var cameraAlertIsPresented = false

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
        .fullScreenCover(isPresented: $cameraIsPresented) {
            CameraCaptureView(
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
                .ignoresSafeArea()
        }
        .alert("카메라를 사용할 수 없습니다", isPresented: $cameraAlertIsPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("기기에 카메라가 있는지 확인하고 설정에서 카메라 접근 권한을 허용해주세요.")
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraAlertIsPresented = true
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
                    cameraAlertIsPresented = true
                }
            }
        case .denied, .restricted:
            cameraAlertIsPresented = true
        @unknown default:
            cameraAlertIsPresented = true
        }
    }

    private func presentCamera() {
        Task {
            let selectedImages = selectedPhotos.compactMap { $0.render() }
            await CameraLiveActivityManager.shared.start(
                selectedImages: selectedImages,
                selectedPhotoCount: selectedPhotos.count,
                contextTitle: contextTitle
            )
            cameraIsPresented = true
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onCapture: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo _: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.onCapture()
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
            parent.dismiss()
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

private struct FeedFolderCard: View {
    let color: Color
    let title: String

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

                miniMemo(width: size.width * 0.52, height: 72, square: 7)
                    .rotationEffect(.degrees(-4))
                    .position(x: size.width * 0.35, y: 40)

                miniMemo(width: size.width * 0.55, height: 78, square: 8)
                    .rotationEffect(.degrees(10))
                    .position(x: size.width * 0.62, y: 36)

                miniMemo(width: size.width * 0.48, height: 70, square: 7)
                    .rotationEffect(.degrees(1))
                    .position(x: size.width * 0.52, y: 48)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.black, lineWidth: 1.05)
                    }
                    .frame(height: 88)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text(title)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .frame(width: size.width - 14)
                    .position(x: size.width / 2, y: size.height - 24)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
    }

    private func miniMemo(width: CGFloat, height: CGFloat, square: CGFloat) -> some View {
        CheckerboardView(squareSize: square)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.black, lineWidth: 0.9)
            }
            .frame(width: width, height: height)
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
                    memo(width: 74, height: 116, square: 9)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoFour,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-12 + (7 * swipeProgress)))
                        .position(x: centerX - 103 * scale, y: 83)
                        .offset(x: -34 * swipeProgress, y: -46 * swipeProgress)

                    memo(width: 79, height: 125, square: 9)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoFive,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-2 + (2 * swipeProgress)))
                        .position(x: centerX - 56 * scale, y: 52)
                        .offset(x: 34 * swipeProgress, y: -43 * swipeProgress)

                    memo(width: 82, height: 124, square: 10)
                        .rotationEffect(.degrees(4))
                        .position(x: centerX - 10 * scale, y: 58)

                    memo(width: 83, height: 126, square: 10)
                        .rotationEffect(.degrees(14))
                        .position(x: centerX + 39 * scale, y: 43)

                    memo(width: 77, height: 120, square: 9)
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

                    memo(width: 72, height: 113, square: 9)
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

                    memo(width: 156, height: 168, square: 12)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoOne,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(-5 + (3 * swipeProgress)))
                        .position(x: centerX - 102 * scale, y: 191)
                        .offset(x: -22 * swipeProgress, y: -45 * swipeProgress)

                    memo(width: 150, height: 172, square: 13)
                        .matchedGeometryEffect(
                            id: IdeaTransitionElement.photoTwo,
                            in: transitionNamespace,
                            isSource: true
                        )
                        .rotationEffect(.degrees(3 - (2 * swipeProgress)))
                        .position(x: centerX - 2 * scale, y: 192)
                        .offset(x: 14 * swipeProgress, y: -57 * swipeProgress)

                    memo(width: 145, height: 158, square: 12)
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

    private func memo(width: CGFloat, height: CGFloat, square: CGFloat) -> some View {
        CheckerboardView(squareSize: square)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.black, lineWidth: 1.05)
            }
            .frame(width: width, height: height)
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
