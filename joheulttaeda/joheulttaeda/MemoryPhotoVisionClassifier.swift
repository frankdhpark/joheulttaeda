import Foundation
import SwiftData
import Vision

struct MemoryPhotoClassificationResult: Sendable {
    let folder: MemoryPhotoFolder
    let identifier: String
    let confidence: Float
}

enum MemoryPhotoVisionClassifier {
    nonisolated static let modelVersion = "vision-taxonomy-v2"

    private struct FolderRule: Sendable {
        let folder: MemoryPhotoFolder
        let minimumScore: Float
        let evidenceWeights: [String: Float]
    }

    private struct Evidence: Sendable {
        let identifier: String
        let contribution: Float
    }

    private struct Candidate: Sendable {
        let folder: MemoryPhotoFolder
        let identifier: String
        let score: Float
        let priority: Int
    }

    private nonisolated static let minimumObservationConfidence: Float = 0.02
    private nonisolated static let minimumWinningMargin: Float = 0.02

    // Vision's general-purpose taxonomy often describes a scene with several
    // related labels instead of one high-confidence concept label. Aggregate
    // those signals so a restaurant photo can be recognized from, for example,
    // restaurant + tableware + plate even when the `food` label itself is low.
    private nonisolated static let rules: [FolderRule] = [
        FolderRule(
            folder: .food,
            minimumScore: 0.22,
            evidenceWeights: [
                "food": 1.50,
                "seafood": 1.30,
                "restaurant": 1.40,
                "dessert": 1.20,
                "frozen_dessert": 1.00,
                "tableware": 0.55,
                "utensil": 0.50,
                "plate": 0.55,
                "bowl": 0.55,
                "fruit": 0.45,
                "berry": 0.45
            ]
        ),
        FolderRule(
            folder: .swimming,
            minimumScore: 0.20,
            evidenceWeights: [
                "swimming": 1.80,
                "swimsuit": 1.70,
                "pool": 1.50,
                "watersport": 1.50,
                "jacuzzi": 1.40,
                "bath": 1.00,
                "bathroom": 0.80,
                "water": 0.35,
                "liquid": 0.20
            ]
        ),
        FolderRule(
            folder: .nap,
            minimumScore: 0.35,
            evidenceWeights: [
                "sleeping": 1.80,
                "sleep": 1.80,
                "nap": 1.80,
                "bed": 1.40,
                "bedroom": 1.30,
                "bedding": 1.10,
                "pillow": 1.00,
                "crib": 0.60
            ]
        ),
        FolderRule(
            folder: .costume,
            minimumScore: 0.30,
            evidenceWeights: [
                "costume": 2.00,
                "santa_claus": 1.80,
                "jack_o_lantern": 1.50,
                "military_uniform": 1.50,
                "kimono": 1.30,
                "mask": 1.30,
                "gas_mask": 1.30,
                "celebration": 0.70
            ]
        ),
        FolderRule(
            folder: .walk,
            minimumScore: 0.42,
            evidenceWeights: [
                "walking": 1.80,
                "stroller": 2.00,
                "walkway": 1.70,
                "sidewalk": 1.70,
                "crosswalk": 1.70,
                "trail": 1.60,
                "hiking": 1.60,
                "crowd": 1.00,
                "sneaker": 0.70,
                "shoes": 0.60,
                "footwear": 0.50,
                "jacket": 0.35,
                "outdoor": 0.25,
                "grass": 0.10,
                "land": 0.10
            ]
        ),
        FolderRule(
            folder: .fashion,
            minimumScore: 0.50,
            evidenceWeights: [
                "fashion": 1.80,
                "outfit": 1.60,
                "clothing": 0.80,
                "footwear": 0.80,
                "shoes": 0.80,
                "wedding_dress": 1.40,
                "leotard": 1.00,
                "beanie": 0.60,
                "jacket": 0.70,
                "jeans": 0.60,
                "baseball_hat": 0.60,
                "hat": 0.25,
                "headgear": 0.25
            ]
        ),
        FolderRule(
            folder: .outing,
            minimumScore: 0.70,
            evidenceWeights: [
                "park": 1.60,
                "amusement_park": 1.60,
                "zoo": 1.60,
                "museum": 1.40,
                "beach": 1.40,
                "picnic": 1.40,
                "landmark": 1.20,
                "outdoor": 0.50,
                "grass": 0.40,
                "land": 0.40,
                "sky": 0.20,
                "animal": 0.50,
                "cow": 0.70
            ]
        )
    ]

    nonisolated static func classify(
        imageURL: URL
    ) async throws -> MemoryPhotoClassificationResult? {
        try await Task.detached(priority: .utility) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(url: imageURL, options: [:])

            try handler.perform([request])

            let observations = (request.results ?? []).sorted {
                $0.confidence > $1.confidence
            }

            #if DEBUG
            for observation in observations.prefix(10) {
                print("Memory Vision:", observation.identifier, observation.confidence)
            }
            #endif

            let folderCandidates = rules.enumerated().compactMap { index, rule in
                candidate(
                    for: rule,
                    priority: index,
                    observations: observations
                )
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) < 0.0001 {
                    return lhs.priority < rhs.priority
                }
                return lhs.score > rhs.score
            }

            #if DEBUG
            for candidate in folderCandidates {
                print(
                    "Memory Vision folder:",
                    candidate.folder.rawValue,
                    candidate.score,
                    candidate.identifier
                )
            }
            #endif

            guard let first = folderCandidates.first else {
                return nil
            }

            let secondScore = folderCandidates.dropFirst().first?.score ?? 0
            guard first.score - secondScore >= minimumWinningMargin else {
                return nil
            }

            return MemoryPhotoClassificationResult(
                folder: first.folder,
                identifier: first.identifier,
                confidence: min(first.score, 1)
            )
        }.value
    }

    private nonisolated static func candidate(
        for rule: FolderRule,
        priority: Int,
        observations: [VNClassificationObservation]
    ) -> Candidate? {
        var score: Float = 0
        var evidence: [Evidence] = []

        for observation in observations where observation.confidence >= minimumObservationConfidence {
            let identifier = normalizedIdentifier(observation.identifier)
            guard let weight = rule.evidenceWeights[identifier] else {
                continue
            }

            let contribution = observation.confidence * weight
            score += contribution
            evidence.append(
                Evidence(
                    identifier: observation.identifier,
                    contribution: contribution
                )
            )
        }

        guard score >= rule.minimumScore else { return nil }

        let evidenceSummary = evidence
            .sorted { $0.contribution > $1.contribution }
            .prefix(3)
            .map(\.identifier)
            .joined(separator: ", ")

        return Candidate(
            folder: rule.folder,
            identifier: evidenceSummary,
            score: score,
            priority: priority
        )
    }

    private nonisolated static func normalizedIdentifier(_ identifier: String) -> String {
        identifier
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

@MainActor
enum MemoryPhotoAutoClassifier {
    private static var inFlightPhotoIDs: Set<UUID> = []

    static func classify(
        recorded: RecordedMemoryPhoto,
        modelContext: ModelContext
    ) async {
        guard inFlightPhotoIDs.insert(recorded.id).inserted else {
            return
        }
        defer { inFlightPhotoIDs.remove(recorded.id) }

        guard let thumbnailURL = MemoryPhotoStorage.fileURL(
            forRelativePath: recorded.thumbnailRelativePath
        ) else {
            markFailed(id: recorded.id, modelContext: modelContext)
            return
        }

        do {
            let result = try await MemoryPhotoVisionClassifier.classify(
                imageURL: thumbnailURL
            )

            guard let photo = fetchPhoto(id: recorded.id, modelContext: modelContext) else {
                return
            }

            guard
                photo.folderID.isEmpty
                    || photo.folderID == MemoryPhotoFolder.uncategorized.rawValue
            else {
                photo.classificationStatusRawValue =
                    MemoryPhotoClassificationStatus.classified.rawValue
                photo.classificationModelVersion = MemoryPhotoVisionClassifier.modelVersion
                photo.classifiedAt = .now
                try modelContext.save()
                return
            }

            guard let result else {
                photo.classificationStatusRawValue =
                    MemoryPhotoClassificationStatus.unclassified.rawValue
                photo.classificationIdentifier = nil
                photo.classificationConfidence = nil
                photo.classificationModelVersion = MemoryPhotoVisionClassifier.modelVersion
                photo.classifiedAt = .now
                try modelContext.save()
                return
            }

            try moveClassifiedPhoto(
                photo,
                result: result,
                modelContext: modelContext
            )
        } catch {
            markFailed(id: recorded.id, modelContext: modelContext)
        }
    }

    private static func moveClassifiedPhoto(
        _ photo: MemoryPhoto,
        result: MemoryPhotoClassificationResult,
        modelContext: ModelContext
    ) throws {
        let previousFolderID = photo.folderID
        let previousOriginalRelativePath = photo.originalRelativePath
        let previousThumbnailRelativePath = photo.thumbnailRelativePath
        let previousClassificationModelVersion = photo.classificationModelVersion
        guard let previousStorageFolderID = previousOriginalRelativePath
            .split(separator: "/")
            .first
            .map(String.init)
        else {
            throw MemoryPhotoStorageError.invalidStoredPath
        }

        let movedPhoto = try MemoryPhotoStorage.moveStoredPhoto(
            id: photo.id,
            originalRelativePath: previousOriginalRelativePath,
            thumbnailRelativePath: previousThumbnailRelativePath,
            toFolderID: result.folder.rawValue
        )

        photo.folderID = result.folder.rawValue
        photo.originalRelativePath = movedPhoto.originalRelativePath
        photo.thumbnailRelativePath = movedPhoto.thumbnailRelativePath
        photo.classificationIdentifier = result.identifier
        photo.classificationConfidence = Double(result.confidence)
        photo.classificationModelVersion = MemoryPhotoVisionClassifier.modelVersion
        photo.classificationStatusRawValue =
            MemoryPhotoClassificationStatus.classified.rawValue
        photo.classifiedAt = .now

        do {
            try modelContext.save()
        } catch {
            if let restoredPhoto = try? MemoryPhotoStorage.moveStoredPhoto(
                id: photo.id,
                originalRelativePath: movedPhoto.originalRelativePath,
                thumbnailRelativePath: movedPhoto.thumbnailRelativePath,
                toFolderID: previousStorageFolderID
            ) {
                photo.folderID = previousFolderID
                photo.originalRelativePath = restoredPhoto.originalRelativePath
                photo.thumbnailRelativePath = restoredPhoto.thumbnailRelativePath
                photo.classificationIdentifier = nil
                photo.classificationConfidence = nil
                photo.classificationModelVersion = previousClassificationModelVersion
                photo.classificationStatusRawValue =
                    MemoryPhotoClassificationStatus.pending.rawValue
                photo.classifiedAt = nil
            }
            throw error
        }
    }

    static func resumePendingClassifications(
        modelContext: ModelContext,
        limit: Int = 20
    ) async {
        reconcileClassifiedStorage(modelContext: modelContext)

        let descriptor = FetchDescriptor<MemoryPhoto>(
            sortBy: [SortDescriptor(\MemoryPhoto.capturedAt, order: .reverse)]
        )

        guard let storedPhotos = try? modelContext.fetch(descriptor) else {
            return
        }

        let currentVersion = MemoryPhotoVisionClassifier.modelVersion
        let photosToClassify = storedPhotos.filter { photo in
            let status = MemoryPhotoClassificationStatus(
                rawValue: photo.classificationStatusRawValue
            )
            if status == .pending {
                return true
            }
            return (status == .unclassified || status == .failed)
                && photo.classificationModelVersion != currentVersion
        }
        .prefix(max(1, limit))

        for photo in photosToClassify {
            await classify(
                recorded: RecordedMemoryPhoto(
                    id: photo.id,
                    thumbnailRelativePath: photo.thumbnailRelativePath
                ),
                modelContext: modelContext
            )
        }
    }

    private static func reconcileClassifiedStorage(
        modelContext: ModelContext
    ) {
        let classifiedStatus = MemoryPhotoClassificationStatus.classified.rawValue
        let uncategorizedFolderID = MemoryPhotoFolder.uncategorized.rawValue
        let descriptor = FetchDescriptor<MemoryPhoto>(
            predicate: #Predicate<MemoryPhoto> { photo in
                photo.classificationStatusRawValue == classifiedStatus
                    && photo.folderID != uncategorizedFolderID
            },
            sortBy: [SortDescriptor(\MemoryPhoto.capturedAt, order: .reverse)]
        )

        guard let classifiedPhotos = try? modelContext.fetch(descriptor) else {
            return
        }

        for photo in classifiedPhotos {
            guard
                let destinationFolder = MemoryPhotoFolder(rawValue: photo.folderID),
                destinationFolder != .uncategorized,
                let currentStorageFolderID = photo.originalRelativePath
                    .split(separator: "/")
                    .first
                    .map(String.init),
                currentStorageFolderID != destinationFolder.rawValue
            else {
                continue
            }

            let previousOriginalRelativePath = photo.originalRelativePath
            let previousThumbnailRelativePath = photo.thumbnailRelativePath
            guard let movedPhoto = try? MemoryPhotoStorage.moveStoredPhoto(
                id: photo.id,
                originalRelativePath: previousOriginalRelativePath,
                thumbnailRelativePath: previousThumbnailRelativePath,
                toFolderID: destinationFolder.rawValue
            ) else {
                continue
            }

            photo.originalRelativePath = movedPhoto.originalRelativePath
            photo.thumbnailRelativePath = movedPhoto.thumbnailRelativePath

            do {
                try modelContext.save()
            } catch {
                if let restoredPhoto = try? MemoryPhotoStorage.moveStoredPhoto(
                    id: photo.id,
                    originalRelativePath: movedPhoto.originalRelativePath,
                    thumbnailRelativePath: movedPhoto.thumbnailRelativePath,
                    toFolderID: currentStorageFolderID
                ) {
                    photo.originalRelativePath = restoredPhoto.originalRelativePath
                    photo.thumbnailRelativePath = restoredPhoto.thumbnailRelativePath
                }
                try? modelContext.save()
            }
        }
    }

    private static func fetchPhoto(
        id: UUID,
        modelContext: ModelContext
    ) -> MemoryPhoto? {
        let photoID = id
        var descriptor = FetchDescriptor<MemoryPhoto>(
            predicate: #Predicate<MemoryPhoto> { photo in
                photo.id == photoID
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private static func markFailed(
        id: UUID,
        modelContext: ModelContext
    ) {
        guard let photo = fetchPhoto(id: id, modelContext: modelContext) else {
            return
        }

        photo.classificationStatusRawValue =
            MemoryPhotoClassificationStatus.failed.rawValue
        photo.classificationIdentifier = nil
        photo.classificationConfidence = nil
        photo.classificationModelVersion = MemoryPhotoVisionClassifier.modelVersion
        photo.classifiedAt = .now
        try? modelContext.save()
    }
}
