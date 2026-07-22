import SwiftData
import SwiftUI

private struct ImportedMemoryPhotoCardContent: Identifiable {
    let id: String
    let image: UIImage?
}

struct MemoryPhotoImportCompletionView: View {
    @Query(sort: \MemoryPhoto.capturedAt, order: .reverse)
    private var storedPhotos: [MemoryPhoto]

    let photoIDs: [UUID]
    let previews: [MemoryPhotoImportPreview]
    let onSavingMoments: () -> Void

    @State private var frontPhotoIndex = 0

    private let background = Color(red: 0.982, green: 0.959, blue: 0.945)
    private let buttonPink = Color(red: 0.98, green: 0.61, blue: 0.80)

    private var importedCards: [ImportedMemoryPhotoCardContent] {
        let photosByID = Dictionary(
            uniqueKeysWithValues: storedPhotos.map { ($0.id, $0) }
        )
        let previewPhotoIDs = Set(previews.compactMap(\.photoID))

        let previewCards = previews.reversed().map {
            ImportedMemoryPhotoCardContent(
                id: "preview-\($0.id)",
                image: $0.image
            )
        }
        let storedCards: [ImportedMemoryPhotoCardContent] = photoIDs
            .reversed()
            .compactMap { photoID in
                guard !previewPhotoIDs.contains(photoID) else { return nil }
                return photosByID[photoID].map {
                    ImportedMemoryPhotoCardContent(
                        id: photoID.uuidString,
                        image: $0.thumbnailImage
                    )
                }
            }

        return previewCards + storedCards
    }

    private var displayedCards: [ImportedMemoryPhotoCardContent] {
        guard !importedCards.isEmpty else { return [] }

        let normalizedIndex = frontPhotoIndex % importedCards.count
        return Array(importedCards[normalizedIndex...])
            + Array(importedCards[..<normalizedIndex])
    }

    private var displayedPhotoPosition: Int {
        guard !importedCards.isEmpty else { return 0 }
        return (frontPhotoIndex % importedCards.count) + 1
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                landscapeLayout(size: proxy.size)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 18)
            } else {
                portraitLayout(size: proxy.size)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom))
            }
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("새 사진 \(importedCards.count)장을 확인했습니다")
        .onChange(of: photoIDs) { _, _ in
            frontPhotoIndex = 0
        }
        .onChange(of: previews.map(\.id)) { _, _ in
            frontPhotoIndex = 0
        }
    }

    private func portraitLayout(size: CGSize) -> some View {
        let compact = size.height < 720
        let cardWidth = min(compact ? 218 : 258, size.width * 0.68)
        let cardHeight = cardWidth * 1.42

        return VStack(spacing: 0) {
            Spacer(minLength: compact ? 4 : 22)

            tappablePhotoStack(
                cardWidth: cardWidth,
                cardHeight: cardHeight
            )
            .frame(height: cardHeight + (compact ? 34 : 58))

            completionMessage
                .padding(.top, compact ? 8 : 14)

            Spacer(minLength: compact ? 14 : 28)

            savingMomentsButton
        }
    }

    private func landscapeLayout(size: CGSize) -> some View {
        let cardHeight = min(size.height * 0.72, 300)
        let cardWidth = cardHeight / 1.42

        return HStack(spacing: 40) {
            tappablePhotoStack(
                cardWidth: cardWidth,
                cardHeight: cardHeight
            )
            .frame(width: cardWidth + 80, height: cardHeight + 54)

            VStack(spacing: 0) {
                Spacer(minLength: 8)
                completionMessage
                Spacer(minLength: 18)
                savingMomentsButton
                Spacer(minLength: 8)
            }
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completionMessage: some View {
        VStack(spacing: 5) {
            Text("Gotcha!")
                .font(.system(size: 30, weight: .black, design: .rounded))

            Text("We’ll save and organize your moment.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.black)
    }

    private var savingMomentsButton: some View {
        completionButton(
            title: "Go to Saving Moments",
            action: onSavingMoments
        )
    }

    private func tappablePhotoStack(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Button(action: showNextPhoto) {
            ZStack {
                ImportedMemoryPhotoStack(
                    cards: displayedCards,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
                .id(displayedCards.first?.id)
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(importedCards.count < 2)
        .accessibilityLabel(
            importedCards.count > 1
                ? "가져온 사진 \(importedCards.count)장 중 "
                    + "\(displayedPhotoPosition)번째, 다음 사진 보기"
                : "가져온 사진"
        )
        .accessibilityHint(
            importedCards.count > 1
                ? "두 번 탭하면 다음 사진을 표시합니다"
                : ""
        )
    }

    private func showNextPhoto() {
        guard importedCards.count > 1 else { return }

        withAnimation(.easeInOut(duration: 0.22)) {
            frontPhotoIndex = (frontPhotoIndex + 1) % importedCards.count
        }
    }

    private func completionButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(buttonPink, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.black, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ImportedMemoryPhotoStack: View {
    let cards: [ImportedMemoryPhotoCardContent]
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private var layerCount: Int {
        min(max(cards.count, 5), 8)
    }

    var body: some View {
        ZStack {
            ForEach(Array((0..<layerCount).reversed()), id: \.self) { index in
                ImportedMemoryPhotoCard(
                    image: index < cards.count ? cards[index].image : nil,
                    isFrontCard: index == 0
                )
                .frame(width: cardWidth, height: cardHeight)
                .rotationEffect(.degrees(rotation(for: index)))
                .offset(offset(for: index))
                .zIndex(Double(layerCount - index))
            }
        }
        .frame(width: cardWidth + 86, height: cardHeight + 66)
        .accessibilityHidden(true)
    }

    private func rotation(for index: Int) -> Double {
        let rotations: [Double] = [0, -4.8, 5.7, -9.4, 9.1, -2.2, 3.1, -11.5]
        return rotations[index % rotations.count]
    }

    private func offset(for index: Int) -> CGSize {
        let offsets: [CGSize] = [
            .zero,
            CGSize(width: -7, height: 3),
            CGSize(width: 9, height: 8),
            CGSize(width: -15, height: 13),
            CGSize(width: 16, height: 17),
            CGSize(width: -2, height: -9),
            CGSize(width: 5, height: -14),
            CGSize(width: -18, height: 20)
        ]
        return offsets[index % offsets.count]
    }
}

private struct ImportedMemoryPhotoCard: View {
    let image: UIImage?
    let isFrontCard: Bool

    var body: some View {
        GeometryReader { proxy in
            let innerWidth = max(1, proxy.size.width - 28)
            let innerHeight = max(1, proxy.size.height - 28)

            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.white)

                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color(red: 0.94, green: 0.94, blue: 0.94)
                            if isFrontCard {
                                Image(systemName: "photo")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundStyle(.gray.opacity(0.65))
                            }
                        }
                    }
                }
                .frame(width: innerWidth, height: innerHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(.black, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(isFrontCard ? 0.08 : 0.025),
                radius: isFrontCard ? 5 : 2,
                y: isFrontCard ? 3 : 1
            )
        }
    }
}
