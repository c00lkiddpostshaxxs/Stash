import SwiftUI

struct DownloadView: View {
    @ObservedObject var manager = DownloadManager.shared

    var body: some View {
        NavigationView {
            Group {
                if manager.downloads.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No downloads yet")
                            .foregroundColor(.gray)
                        Text("Tap a downloadable file in the browser")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(manager.downloads) { item in
                            DownloadRow(item: item)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { manager.cancelDownload(id: manager.downloads[$0].id) }
                            manager.downloads.remove(atOffsets: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
        }
    }
}

struct DownloadRow: View {
    let item: DownloadItem

    var statusColor: Color {
        switch item.status {
        case .completed:  return .green
        case .failed:     return .red
        case .downloading: return .blue
        case .paused:     return .orange
        case .queued:     return .gray
        }
    }

    var statusIcon: String {
        switch item.status {
        case .completed:   return "checkmark.circle.fill"
        case .failed:      return "xmark.circle.fill"
        case .downloading: return "arrow.down.circle.fill"
        case .paused:      return "pause.circle.fill"
        case .queued:      return "clock.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(item.filename)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(item.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            if item.status == .downloading {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
                HStack {
                    Text(formatBytes(item.bytesDownloaded))
                    Text("/")
                    Text(formatBytes(item.fileSize))
                    Spacer()
                    Text(String(format: "%.0f%%", item.progress * 100))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
