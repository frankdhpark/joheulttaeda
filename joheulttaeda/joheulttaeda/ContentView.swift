//
//  ContentView.swift
//  joheulttaeda
//
//  Created by donghun park on 7/20/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: HomeTab = .home
    @State private var expandedFolder: IdeaFolder?

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
                    IdeaFeedView { folder in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            expandedFolder = folder
                        }
                    }
                        .frame(width: width, height: height)
                        .transition(.opacity)
                } else if selectedTab == .memory {
                    MemorySectionView {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = .home
                        }
                    }
                    .frame(width: width, height: height)
                    .transition(.opacity)
                } else {
                    Clothesline()
                        .stroke(
                            DesignColor.rope,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: width, height: lineY + 28)

                    HeaderView()
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

                    IdeaStackView()
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
    let onFolderTap: (IdeaFolder) -> Void

    @State private var ageFilter = "Age"
    @State private var seasonFilter = "Season"
    @State private var spotFilter = "Spot"

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

                        HStack(alignment: .top, spacing: columnSpacing) {
                            VStack(spacing: 24) {
                                folderButton(.amusementPark, width: cardWidth)

                                folderButton(.cherryBlossom, width: cardWidth)

                                FeedPhotoCard(squareSize: 8)
                                    .frame(width: cardWidth, height: cardWidth * 0.82)

                                FeedPhotoCard(squareSize: 13)
                                    .frame(width: cardWidth, height: cardWidth * 1.56)

                                folderButton(.warmAfternoon, width: cardWidth)
                            }

                            VStack(spacing: 24) {
                                FeedPhotoCard(squareSize: 14)
                                    .frame(width: cardWidth, height: cardWidth * 1.55)

                                folderButton(.rainyDay, width: cardWidth)

                                FeedPhotoCard(squareSize: 13)
                                    .frame(width: cardWidth, height: cardWidth * 1.60)

                                FeedPhotoCard(squareSize: 9)
                                    .frame(width: cardWidth, height: cardWidth * 0.86)

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
                .allowsHitTesting(false)

                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignColor.text)
                    .padding(.bottom, 58)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("아이디어 피드")
    }

    private func folderButton(_ folder: IdeaFolder, width: CGFloat) -> some View {
        Button {
            onFolderTap(folder)
        } label: {
            FeedFolderCard(color: folder.color, title: folder.title)
                .frame(width: width, height: 126)
        }
        .buttonStyle(.plain)
        .accessibilityHint("폴더의 사진을 펼칩니다")
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
}

private struct ExpandedFolderView: View {
    let folder: IdeaFolder
    let onDismiss: () -> Void

    @State private var photosAreExpanded = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let photoWidth = min(166, size.width * 0.40)

            ZStack {
                DesignColor.background
                    .ignoresSafeArea()

                backgroundFolder(color: DesignColor.pink, width: photoWidth * 1.10, height: 150)
                    .position(x: size.width * 0.31, y: size.height * 0.42)

                backgroundFolder(color: DesignColor.blue, width: photoWidth * 1.04, height: 150)
                    .position(x: size.width * 0.72, y: size.height * 0.57)

                backgroundFolder(color: DesignColor.yellow, width: photoWidth * 1.10, height: 145)
                    .position(x: size.width * 0.34, y: size.height * 0.76)

                expandedPhoto(
                    width: photoWidth,
                    height: photoWidth * 1.50,
                    square: 13,
                    angle: 4,
                    x: size.width * 0.36,
                    y: size.height * 0.26,
                    index: 0,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth,
                    height: photoWidth * 1.47,
                    square: 13,
                    angle: -4,
                    x: size.width * 0.68,
                    y: size.height * 0.27,
                    index: 1,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth * 0.98,
                    height: photoWidth * 0.95,
                    square: 9,
                    angle: 3,
                    x: size.width * 0.36,
                    y: size.height * 0.39,
                    index: 2,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth * 0.98,
                    height: photoWidth * 0.98,
                    square: 10,
                    angle: -7,
                    x: size.width * 0.70,
                    y: size.height * 0.43,
                    index: 3,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth * 0.96,
                    height: photoWidth * 1.47,
                    square: 15,
                    angle: -12,
                    x: size.width * 0.35,
                    y: size.height * 0.58,
                    index: 4,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth * 0.96,
                    height: photoWidth * 1.45,
                    square: 14,
                    angle: 6,
                    x: size.width * 0.69,
                    y: size.height * 0.61,
                    index: 5,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth * 0.94,
                    height: photoWidth * 1.03,
                    square: 10,
                    angle: -3,
                    x: size.width * 0.35,
                    y: size.height * 0.79,
                    index: 6,
                    canvasHeight: size.height
                )

                expandedPhoto(
                    width: photoWidth * 0.92,
                    height: photoWidth * 1.02,
                    square: 9,
                    angle: 17,
                    x: size.width * 0.68,
                    y: size.height * 0.80,
                    index: 7,
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.height > 80 {
                            onDismiss()
                        }
                    }
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                photosAreExpanded = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(folder.title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAction(.escape, onDismiss)
    }

    private func expandedPhoto(
        width: CGFloat,
        height: CGFloat,
        square: CGFloat,
        angle: Double,
        x: CGFloat,
        y: CGFloat,
        index: Int,
        canvasHeight: CGFloat
    ) -> some View {
        ExpandedPhotoCard(squareSize: square)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(photosAreExpanded ? angle : 0))
            .scaleEffect(photosAreExpanded ? 1 : 0.72)
            .position(x: x, y: y)
            .offset(y: photosAreExpanded ? 0 : canvasHeight - y + 40)
            .opacity(photosAreExpanded ? 1 : 0)
            .animation(
                .spring(response: 0.58, dampingFraction: 0.76)
                    .delay(Double(index) * 0.035),
                value: photosAreExpanded
            )
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
    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))

                Text("Memory")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
            }
            .foregroundStyle(DesignColor.text)
            .offset(y: 10)

            ProfileButton()
                .frame(width: 42, height: 42)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 18)
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

private struct IdeaStackView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let centerX = size.width / 2
            let scale = min(1, size.width / 390)

            ZStack {
                ZStack {
                    memo(width: 74, height: 116, square: 9)
                        .rotationEffect(.degrees(-12))
                        .position(x: centerX - 103 * scale, y: 83)

                    memo(width: 79, height: 125, square: 9)
                        .rotationEffect(.degrees(-2))
                        .position(x: centerX - 56 * scale, y: 52)

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
                        .rotationEffect(.degrees(-8))
                        .position(x: centerX - 77 * scale, y: 117)

                    folder(color: DesignColor.yellow, width: 246, height: 137)
                        .rotationEffect(.degrees(2))
                        .position(x: centerX, y: 103)

                    memo(width: 72, height: 113, square: 9)
                        .rotationEffect(.degrees(-1))
                        .position(x: centerX + 27 * scale, y: 96)

                    folder(color: DesignColor.blue, width: 216, height: 124)
                        .rotationEffect(.degrees(5))
                        .position(x: centerX + 91 * scale, y: 128)

                    memo(width: 156, height: 168, square: 12)
                        .rotationEffect(.degrees(-5))
                        .position(x: centerX - 102 * scale, y: 191)

                    memo(width: 150, height: 172, square: 13)
                        .rotationEffect(.degrees(3))
                        .position(x: centerX - 2 * scale, y: 192)

                    memo(width: 145, height: 158, square: 12)
                        .rotationEffect(.degrees(5))
                        .position(x: centerX + 102 * scale, y: 196)
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

                    Image(systemName: "chevron.down")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(DesignColor.text)
                .position(x: centerX, y: size.height - 67)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("아이디어 카드 모음")
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
            withAnimation(.easeInOut(duration: 0.18)) {
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
