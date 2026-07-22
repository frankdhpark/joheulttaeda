import Foundation
import SwiftUI
import WebKit

private struct InstagramOEmbedRequest: Encodable {
    let sourceURL: URL
}

private struct InstagramOEmbedResponse: Decodable {
    let html: String
}

private struct InstagramOEmbedErrorResponse: Decodable {
    let message: String?
}

private enum InstagramEmbedContent: Equatable {
    case html(String)
    case remote(URL)
}

private enum InstagramOEmbedError: LocalizedError {
    case invalidEndpoint
    case invalidInstagramURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Instagram oEmbed 서버 주소가 올바르지 않습니다."
        case .invalidInstagramURL:
            "지원하지 않는 Instagram 주소입니다."
        case .invalidResponse:
            "Instagram 플레이어 응답을 확인할 수 없습니다."
        case .server(let message):
            message
        }
    }
}

private struct InstagramOEmbedClient {
    private static let endpointInfoKey = "InstagramOEmbedResolverURL"
    private static let apiKeyInfoKey = "InstagramOEmbedAPIKey"

    let session: URLSession
    let bundle: Bundle

    init(session: URLSession = .shared, bundle: Bundle = .main) {
        self.session = session
        self.bundle = bundle
    }

    func fetchContent(for sourceURL: URL) async throws -> InstagramEmbedContent {
        guard Self.isSupportedInstagramURL(sourceURL) else {
            throw InstagramOEmbedError.invalidInstagramURL
        }

        guard let endpoint = try configuredEndpoint() else {
            return .remote(try Self.directEmbedURL(for: sourceURL))
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = configuredAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        request.httpBody = try JSONEncoder().encode(InstagramOEmbedRequest(sourceURL: sourceURL))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstagramOEmbedError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseMessage = try? JSONDecoder().decode(
                InstagramOEmbedErrorResponse.self,
                from: data
            ).message
            throw InstagramOEmbedError.server(
                responseMessage ?? "Instagram 플레이어를 불러오지 못했습니다."
            )
        }

        let responseBody = try JSONDecoder().decode(InstagramOEmbedResponse.self, from: data)
        let html = responseBody.html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !html.isEmpty, html.utf8.count <= 1_000_000 else {
            throw InstagramOEmbedError.invalidResponse
        }
        return .html(html)
    }

    private func configuredEndpoint() throws -> URL? {
        #if DEBUG
        let environmentValue = ProcessInfo.processInfo.environment["INSTAGRAM_OEMBED_RESOLVER_URL"]
        #else
        let environmentValue: String? = nil
        #endif

        let configuredValue = environmentValue ?? bundle.object(
            forInfoDictionaryKey: Self.endpointInfoKey
        ) as? String
        guard let configuredValue else { return nil }
        let trimmedValue = configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }
        guard let endpoint = URL(string: trimmedValue), Self.isAllowedEndpoint(endpoint) else {
            throw InstagramOEmbedError.invalidEndpoint
        }
        return endpoint
    }

    private func configuredAPIKey() -> String? {
        #if DEBUG
        let environmentValue = ProcessInfo.processInfo.environment["INSTAGRAM_OEMBED_API_KEY"]
        #else
        let environmentValue: String? = nil
        #endif

        let configuredValue = environmentValue ?? bundle.object(
            forInfoDictionaryKey: Self.apiKeyInfoKey
        ) as? String
        let trimmedValue = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }

    private static func isSupportedInstagramURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host == "instagram.com" || host == "www.instagram.com" else {
            return false
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let firstComponent = pathComponents.first?.lowercased() else { return false }
        return ["p", "reel", "reels", "tv"].contains(firstComponent) && pathComponents.count >= 2
    }

    private static func directEmbedURL(for sourceURL: URL) throws -> URL {
        let pathComponents = sourceURL.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else {
            throw InstagramOEmbedError.invalidInstagramURL
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.instagram.com"
        components.path = "/\(pathComponents[0].lowercased())/\(pathComponents[1])/embed/"
        guard let embedURL = components.url else {
            throw InstagramOEmbedError.invalidInstagramURL
        }
        return embedURL
    }

    private static func isAllowedEndpoint(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else {
            return false
        }
        if scheme == "https" { return true }

        #if DEBUG
        return scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)
        #else
        return false
        #endif
    }
}

struct InstagramEmbedPlayerView: View {
    let title: String
    let sourceURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var embedContent: InstagramEmbedContent?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var reloadID = UUID()

    var body: some View {
        NavigationStack {
            Group {
                if let embedContent {
                    InstagramEmbedWebView(content: embedContent, sourceURL: sourceURL)
                        .ignoresSafeArea(edges: .bottom)
                } else if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Instagram 플레이어를 불러오는 중입니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    unavailableView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openURL(sourceURL)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .accessibilityLabel("Instagram에서 열기")
                }
            }
        }
        .task(id: reloadID) {
            await loadEmbed()
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("플레이어를 표시할 수 없습니다", systemImage: "play.slash")
        } description: {
            Text(errorMessage ?? "잠시 후 다시 시도해 주세요.")
        } actions: {
            Button("다시 시도") {
                reloadID = UUID()
            }
            .buttonStyle(.borderedProminent)

            Button("Instagram에서 열기") {
                openURL(sourceURL)
            }
            .buttonStyle(.bordered)
        }
    }

    @MainActor
    private func loadEmbed() async {
        isLoading = true
        embedContent = nil
        errorMessage = nil

        do {
            embedContent = try await InstagramOEmbedClient().fetchContent(for: sourceURL)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct InstagramEmbedWebView: UIViewRepresentable {
    let content: InstagramEmbedContent
    let sourceURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedContent != content else { return }
        context.coordinator.loadedContent = content

        switch content {
        case .html:
            webView.loadHTMLString(documentHTML, baseURL: sourceURL)
        case .remote(let embedURL):
            var request = URLRequest(url: embedURL)
            request.timeoutInterval = 15
            webView.load(request)
        }
    }

    private var documentHTML: String {
        guard case .html(let embedHTML) = content else { return "" }
        return """
        <!doctype html>
        <html lang="ko">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <style>
            :root { color-scheme: light dark; }
            html, body { margin: 0; padding: 0; min-height: 100%; background: transparent; }
            body { display: flex; justify-content: center; padding: 12px; box-sizing: border-box; }
            .instagram-media { width: 100% !important; min-width: 0 !important; max-width: 658px !important; margin: 0 auto !important; }
          </style>
        </head>
        <body>
          \(embedHTML)
        </body>
        </html>
        """
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var loadedContent: InstagramEmbedContent?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let targetURL = navigationAction.request.url,
                  ["http", "https"].contains(targetURL.scheme?.lowercased() ?? "") else {
                decisionHandler(.allow)
                return
            }

            UIApplication.shared.open(targetURL)
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let targetURL = navigationAction.request.url,
               ["http", "https"].contains(targetURL.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(targetURL)
            }
            return nil
        }
    }
}
