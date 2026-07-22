import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let folderButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var folders = IdeaFolderSnapshot.defaults
    private var selectedFolderID = "idea-inbox"
    private var isSaving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        loadFolderSnapshot()
        configureView()
        configureFolderMenu()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        preferredContentSize = CGSize(width: 360, height: 270)

        titleLabel.text = "Idea에 저장"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center

        statusLabel.text = "저장할 폴더를 선택해주세요."
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        folderButton.configuration = .bordered()
        folderButton.showsMenuAsPrimaryAction = true

        saveButton.configuration = .filled()
        saveButton.setTitle("저장", for: .normal)
        saveButton.addTarget(self, action: #selector(saveSharedContent), for: .touchUpInside)

        cancelButton.setTitle("취소", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let actionStack = UIStackView(arrangedSubviews: [cancelButton, saveButton])
        actionStack.axis = .horizontal
        actionStack.spacing = 12
        actionStack.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            statusLabel,
            folderButton,
            activityIndicator,
            actionStack
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            folderButton.heightAnchor.constraint(equalToConstant: 44),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureFolderMenu() {
        let selectedTitle = folders.first(where: { $0.id == selectedFolderID })?.title
            ?? "새 아이디어"
        folderButton.setTitle(selectedTitle, for: .normal)
        folderButton.menu = UIMenu(
            title: "Idea 폴더",
            children: folders.map { folder in
                UIAction(
                    title: folder.title,
                    state: folder.id == selectedFolderID ? .on : .off
                ) { [weak self] _ in
                    self?.selectedFolderID = folder.id
                    self?.configureFolderMenu()
                }
            }
        )
    }

    private func loadFolderSnapshot() {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: IdeaImportAppGroup.identifier
        ) else {
            return
        }
        let snapshotURL = container.appendingPathComponent(IdeaImportAppGroup.folderSnapshotFileName)
        guard let data = try? Data(contentsOf: snapshotURL),
              let decoded = try? JSONDecoder.ideaImportDecoder().decode(
                [IdeaFolderSnapshot].self,
                from: data
              ),
              !decoded.isEmpty else {
            return
        }
        folders = decoded
    }

    @objc
    private func saveSharedContent() {
        guard !isSaving else { return }
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showFailure(ShareImportError.noSharedContent)
            return
        }

        let providers = extensionItems.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            showFailure(ShareImportError.noSharedContent)
            return
        }

        do {
            let job = try makeJobDirectory()
            beginSavingUI()
            collect(providers: providers, into: job)
        } catch {
            showFailure(error)
        }
    }

    private func collect(providers: [NSItemProvider], into jobDirectory: URL) {
        let accumulator = ShareImportAccumulator()
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                loadFile(
                    from: provider,
                    type: .image,
                    typeIdentifier: UTType.image.identifier,
                    index: index,
                    jobDirectory: jobDirectory,
                    accumulator: accumulator,
                    group: group
                )
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                loadFile(
                    from: provider,
                    type: .video,
                    typeIdentifier: UTType.movie.identifier,
                    index: index,
                    jobDirectory: jobDirectory,
                    accumulator: accumulator,
                    group: group
                )
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                loadURL(from: provider, accumulator: accumulator, group: group)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                loadTextURL(from: provider, accumulator: accumulator, group: group)
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finishCollecting(accumulator: accumulator, jobDirectory: jobDirectory)
        }
    }

    private func loadFile(
        from provider: NSItemProvider,
        type: IncomingMediaType,
        typeIdentifier: String,
        index: Int,
        jobDirectory: URL,
        accumulator: ShareImportAccumulator,
        group: DispatchGroup
    ) {
        group.enter()
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            defer { group.leave() }
            guard let url else {
                accumulator.record(error: error ?? ShareImportError.unreadableAttachment)
                return
            }

            let fallbackExtension = type == .image ? "jpg" : "mp4"
            let sourceExtension = url.pathExtension.lowercased()
            let fileExtension = sourceExtension.isEmpty ? fallbackExtension : sourceExtension
            let fileName = "shared-\(index).\(fileExtension)"
            let destination = jobDirectory.appendingPathComponent(fileName)

            do {
                try FileManager.default.copyItem(at: url, to: destination)
                accumulator.add(
                    attachment: IncomingAttachment(mediaType: type, relativePath: fileName)
                )
            } catch {
                accumulator.record(error: error)
            }
        }
    }

    private func loadURL(
        from provider: NSItemProvider,
        accumulator: ShareImportAccumulator,
        group: DispatchGroup
    ) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
            defer { group.leave() }
            let candidate: URL?
            if let url = item as? URL {
                candidate = url
            } else if let url = item as? NSURL {
                candidate = url as URL
            } else if let data = item as? Data,
                      let string = String(data: data, encoding: .utf8) {
                candidate = self.instagramURL(in: string)
            } else {
                candidate = nil
            }

            if let candidate, let url = self.validatedInstagramURL(candidate) {
                accumulator.add(sourceURL: url)
            } else {
                accumulator.record(error: error ?? ShareImportError.unsupportedURL)
            }
        }
    }

    private func loadTextURL(
        from provider: NSItemProvider,
        accumulator: ShareImportAccumulator,
        group: DispatchGroup
    ) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
            defer { group.leave() }
            let text = (item as? String) ?? (item as? NSString).map(String.init)
            if let text, let url = self.instagramURL(in: text) {
                accumulator.add(sourceURL: url)
            } else {
                accumulator.record(error: error ?? ShareImportError.unsupportedURL)
            }
        }
    }

    private func finishCollecting(
        accumulator: ShareImportAccumulator,
        jobDirectory: URL
    ) {
        let snapshot = accumulator.snapshot()
        var attachments = snapshot.attachments

        if attachments.isEmpty, snapshot.sourceURL != nil {
            attachments = [IncomingAttachment(mediaType: .instagramURL, relativePath: nil)]
        }

        guard !attachments.isEmpty else {
            try? FileManager.default.removeItem(at: jobDirectory)
            showFailure(snapshot.error ?? ShareImportError.noSupportedContent)
            return
        }

        do {
            let manifest = IdeaImportManifest(
                id: UUID(uuidString: jobDirectory.lastPathComponent) ?? UUID(),
                destinationFolderID: selectedFolderID,
                sourceURL: snapshot.sourceURL,
                attachments: attachments,
                createdAt: Date()
            )
            let data = try JSONEncoder.ideaImportEncoder().encode(manifest)
            let manifestURL = jobDirectory.appendingPathComponent(IdeaImportAppGroup.manifestFileName)
            try data.write(to: manifestURL, options: .atomic)
            statusLabel.text = "Idea 폴더에 저장할 준비가 끝났습니다."

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        } catch {
            try? FileManager.default.removeItem(at: jobDirectory)
            showFailure(error)
        }
    }

    private func makeJobDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: IdeaImportAppGroup.identifier
        ) else {
            throw ShareImportError.appGroupUnavailable
        }
        let incoming = container.appendingPathComponent(
            IdeaImportAppGroup.incomingDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)
        let job = incoming.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: job, withIntermediateDirectories: false)
        return job
    }

    private func instagramURL(in text: String) -> URL? {
        let pattern = #"https?://[^\s<>\"]+"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              let range = Range(match.range, in: text) else {
            return nil
        }
        let rawURL = String(text[range]).trimmingCharacters(
            in: CharacterSet(charactersIn: ".,;:!?)]}")
        )
        return URL(string: rawURL).flatMap(validatedInstagramURL)
    }

    private func validatedInstagramURL(_ url: URL) -> URL? {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return nil
        }
        guard host == "instagram.com" || host.hasSuffix(".instagram.com") else {
            return nil
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.url
    }

    private func beginSavingUI() {
        isSaving = true
        activityIndicator.startAnimating()
        statusLabel.text = "공유 항목을 가져오는 중입니다…"
        folderButton.isEnabled = false
        saveButton.isEnabled = false
        cancelButton.isEnabled = false
    }

    private func showFailure(_ error: Error) {
        isSaving = false
        activityIndicator.stopAnimating()
        statusLabel.text = error.localizedDescription
        statusLabel.textColor = .systemRed
        folderButton.isEnabled = true
        saveButton.isEnabled = true
        cancelButton.isEnabled = true
    }

    @objc
    private func cancel() {
        extensionContext?.cancelRequest(withError: ShareImportError.cancelled)
    }
}

private final class ShareImportAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var attachments: [IncomingAttachment] = []
    private var sourceURL: URL?
    private var firstError: Error?

    func add(attachment: IncomingAttachment) {
        lock.lock()
        attachments.append(attachment)
        lock.unlock()
    }

    func add(sourceURL: URL) {
        lock.lock()
        if self.sourceURL == nil {
            self.sourceURL = sourceURL
        }
        lock.unlock()
    }

    func record(error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func snapshot() -> (attachments: [IncomingAttachment], sourceURL: URL?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        return (attachments.sorted { ($0.relativePath ?? "") < ($1.relativePath ?? "") }, sourceURL, firstError)
    }
}

private enum ShareImportError: LocalizedError {
    case appGroupUnavailable
    case noSharedContent
    case noSupportedContent
    case unreadableAttachment
    case unsupportedURL
    case cancelled

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "공유 저장 공간을 열 수 없습니다."
        case .noSharedContent:
            "공유된 항목이 없습니다."
        case .noSupportedContent:
            "지원되는 사진, 영상 또는 Instagram 링크가 없습니다."
        case .unreadableAttachment:
            "공유된 파일을 읽을 수 없습니다."
        case .unsupportedURL:
            "Instagram 게시물 링크를 찾을 수 없습니다."
        case .cancelled:
            "사용자가 가져오기를 취소했습니다."
        }
    }
}
