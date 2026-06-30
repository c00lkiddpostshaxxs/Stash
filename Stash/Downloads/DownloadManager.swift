import Foundation
import BackgroundTasks

struct DownloadItem: Identifiable, Codable {
    var id: UUID = UUID()
    var url: String
    var filename: String
    var progress: Double = 0
    var status: Status = .queued
    var fileSize: Int64 = 0
    var bytesDownloaded: Int64 = 0

    enum Status: String, Codable {
        case queued, downloading, paused, completed, failed
    }
}

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []
    var backgroundCompletionHandler: (() -> Void)?

    private var session: URLSession!
    private var tasks: [UUID: URLSessionDownloadTask] = [:]

    private let downloadableExtensions = [
        "zip", "rar", "7z", "tar", "gz",
        "mp4", "mov", "mkv", "avi", "mp3", "m4a",
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "apk", "ipa", "exe", "dmg",
        "jpg", "jpeg", "png", "gif", "webp"
    ]

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.stash.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 86400
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        loadDownloads()
    }

    func isDownloadable(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return downloadableExtensions.contains(ext)
    }

    func startDownload(url: URL) {
        var item = DownloadItem(
            url: url.absoluteString,
            filename: url.lastPathComponent.isEmpty ? "download_\(Date().timeIntervalSince1970)" : url.lastPathComponent
        )
        item.status = .downloading
        
        DispatchQueue.main.async {
            self.downloads.append(item)
            self.saveDownloads()
        }

        let task = session.downloadTask(with: url)
        task.taskDescription = item.id.uuidString
        tasks[item.id] = task
        task.resume()
        
        print("Download started: \(item.filename)")
    }

    func cancelDownload(id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            downloads[index].status = .failed
        }
        saveDownloads()
    }

    func handleBackgroundTask(task: BGAppRefreshTask) {
        scheduleNextRefresh()
        task.setTaskCompleted(success: true)
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.stash.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func destinationURL(for filename: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(filename)
    }

    private func tempURL(for filename: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("\(filename).stash")
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let idString = downloadTask.taskDescription,
              let id = UUID(uuidString: idString),
              let index = downloads.firstIndex(where: { $0.id == id }) else { return }

        let tempDest = tempURL(for: downloads[index].filename)
        let finalDest = destinationURL(for: downloads[index].filename)
        
        do {
            try FileManager.default.moveItem(at: location, to: tempDest)
            try? FileManager.default.removeItem(at: finalDest)
            try FileManager.default.moveItem(at: tempDest, to: finalDest)
        } catch {
            print("File move error: \(error)")
            DispatchQueue.main.async {
                self.downloads[index].status = .failed
                self.saveDownloads()
            }
            return
        }

        DispatchQueue.main.async {
            self.downloads[index].status = .completed
            self.downloads[index].progress = 1.0
            self.saveDownloads()
            print("Download completed: \(self.downloads[index].filename)")
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let idString = downloadTask.taskDescription,
              let id = UUID(uuidString: idString),
              let index = downloads.firstIndex(where: { $0.id == id }) else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0

        DispatchQueue.main.async {
            self.downloads[index].progress = progress
            self.downloads[index].bytesDownloaded = totalBytesWritten
            self.downloads[index].fileSize = totalBytesExpectedToWrite
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let idString = task.taskDescription,
              let id = UUID(uuidString: idString),
              let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        
        print("Download failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.downloads[index].status = .failed
            self.saveDownloads()
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    private func saveDownloads() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: "stash_downloads")
        }
    }

    private func loadDownloads() {
        if let data = UserDefaults.standard.data(forKey: "stash_downloads"),
           let saved = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            downloads = saved.map {
                var item = $0
                if item.status == .downloading { item.status = .paused }
                return item
            }
        }
    }
}
