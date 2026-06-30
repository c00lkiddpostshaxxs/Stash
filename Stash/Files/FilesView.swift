import SwiftUI
import QuickLook

struct FilesView: View {
    @State private var files: [FileItem] = []
    @State private var selectedURL: URL?
    @State private var showingPreview = false
    @State private var showingDeleteAlert = false
    @State private var fileToDelete: FileItem?

    let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    var body: some View {
        NavigationView {
            Group {
                if files.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No files yet")
                            .foregroundColor(.gray)
                        Text("Downloaded files will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(files) { file in
                            FileRow(file: file)
                                .onTapGesture {
                                    selectedURL = file.url
                                    showingPreview = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        fileToDelete = file
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        share(file: file)
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadFiles) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingPreview) {
                if let url = selectedURL {
                    QuickLookView(url: url)
                }
            }
            .alert("Delete File", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete { deleteFile(file) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(fileToDelete?.name ?? "")?")
            }
        }
        .onAppear(perform: loadFiles)
    }

    func loadFiles() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: docsURL,
                                                          includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                                                          options: .skipsHiddenFiles) else { return }
        files = contents.map { url in
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            return FileItem(url: url,
                            name: url.lastPathComponent,
                            size: Int64(attrs?.fileSize ?? 0),
                            date: attrs?.creationDate ?? Date())
        }.sorted { $0.date > $1.date }
    }

    func deleteFile(_ file: FileItem) {
        try? FileManager.default.removeItem(at: file.url)
        loadFiles()
    }

    func share(file: FileItem) {
        let vc = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(vc, animated: true)
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let date: Date
}

struct FileRow: View {
    let file: FileItem

    var icon: String {
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "mp4", "mov", "mkv", "avi": return "film"
        case "mp3", "m4a", "wav": return "music.note"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo"
        case "zip", "rar", "7z": return "archivebox"
        case "ipa", "apk": return "app.badge"
        default: return "doc"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack {
                    Text(formatBytes(file.size))
                    Text("·")
                    Text(file.date, style: .date)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
