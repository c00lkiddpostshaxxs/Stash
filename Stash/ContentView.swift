import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BrowserView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }

            DownloadView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

            FilesView()
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
        }
        .accentColor(.blue)
    }
}
