import SwiftUI
import WebKit

struct BrowserView: View {
    @StateObject private var vm = WebViewModel()
    @State private var editingURL = false
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            if vm.isLoading {
                ProgressView(value: vm.progress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }
            WebViewRepresentable(webView: vm.webView)
            toolbar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    var addressBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .opacity(vm.urlString.hasPrefix("https") ? 1 : 0)

                if editingURL {
                    TextField("Search or URL", text: $inputText, onCommit: {
                        vm.load(inputText)
                        editingURL = false
                    })
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                } else {
                    Text(vm.pageTitle.isEmpty ? vm.urlString : vm.pageTitle)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .onTapGesture {
                            inputText = vm.urlString
                            editingURL = true
                        }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if vm.isLoading {
                Button(action: vm.stop) {
                    Image(systemName: "xmark")
                }
            } else {
                Button(action: vm.reload) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    var toolbar: some View {
        HStack {
            Button(action: vm.goBack) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .disabled(!vm.canGoBack)

            Spacer()

            Button(action: vm.goForward) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(!vm.canGoForward)

            Spacer()

            Button {
                UIPasteboard.general.string = vm.urlString
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.title3)
            }

            Spacer()

            Button {
                shareURL()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    func shareURL() {
        guard let url = URL(string: vm.urlString) else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(vc, animated: true)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
