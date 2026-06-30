import SwiftUI
import WebKit
import Combine

class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var urlString: String = "https://google.com"
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0
    @Published var pageTitle: String = ""

    var webView: WKWebView
    private var progressObserver: NSKeyValueObservation?

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        progressObserver = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progress = webView.estimatedProgress
            }
        }

        load(urlString)
    }

    func load(_ input: String) {
        var raw = input.trimmingCharacters(in: .whitespaces)
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            if raw.contains(".") && !raw.contains(" ") {
                raw = "https://\(raw)"
            } else {
                raw = "https://www.google.com/search?q=\(raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw)"
            }
        }
        urlString = raw
        if let url = URL(string: raw) {
            webView.load(URLRequest(url: url))
        }
    }

    func goBack()    { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload()    { webView.reload() }
    func stop()      { webView.stopLoading() }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let url = webView.url { urlString = url.absoluteString }
        pageTitle = webView.title ?? ""
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           DownloadManager.shared.isDownloadable(url: url) {
            DownloadManager.shared.startDownload(url: url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
