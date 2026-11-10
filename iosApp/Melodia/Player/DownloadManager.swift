import Foundation
import SwiftUI

enum DownloadStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MelodiaDownloads", isDirectory: true)
    }

    static func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func fileURL(id: Int64, extension ext: String) -> URL {
        directory.appendingPathComponent(String(id)).appendingPathExtension(ext)
    }

    static func findFile(id: Int64) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return nil }
        return files.first { $0.deletingPathExtension().lastPathComponent == String(id) }
    }
}

struct DownloadRecord: Codable, Identifiable {
    let songID: Int64
    let name: String
    let artist: String
    let albumName: String
    let coverURL: String
    let durationMs: Int64
    let quality: String
    let fileExtension: String
    let fileSize: Int64
    let createdAt: Date

    var id: Int64 { songID }

    var track: Track {
        Track(
            id: songID,
            name: name,
            artists: [Artist(id: 0, name: artist)],
            album: Album(id: 0, name: albumName, picUrl: coverURL),
            durationMs: durationMs
        )
    }

    var sizeText: String {
        guard fileSize > 0 else { return "" }
        if fileSize >= 1024 * 1024 * 1024 {
            return String(format: "%.2f GB", Double(fileSize) / 1024 / 1024 / 1024)
        }
        return String(format: "%.1f MB", Double(fileSize) / 1024 / 1024)
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var records: [DownloadRecord] = []
    @Published private(set) var activeSongIDs: Set<Int64> = []
    @Published var lastErrorMessage: String?

    private let defaultsKey = "melodia.downloads.v1"
    private let client = NeteaseClient.shared

    private init() {
        load()
    }

    var totalBytes: Int64 {
        records.reduce(0) { $0 + $1.fileSize }
    }

    func isDownloading(_ songID: Int64) -> Bool {
        activeSongIDs.contains(songID)
    }

    func record(for songID: Int64) -> DownloadRecord? {
        records.first { $0.songID == songID }
    }

    func localURL(for songID: Int64) -> URL? {
        DownloadStore.findFile(id: songID)
    }

    func download(_ track: Track, quality: AudioQuality) {
        guard track.id > 0, !activeSongIDs.contains(track.id) else { return }
        activeSongIDs.insert(track.id)
        lastErrorMessage = nil

        Task {
            defer { activeSongIDs.remove(track.id) }
            do {
                try DownloadStore.prepare()
                let remoteURL = try await client.songURL(id: track.id, level: quality.rawValue)
                let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw NeteaseError.server(http.statusCode, "下载失败")
                }

                let ext = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
                let destination = DownloadStore.fileURL(id: track.id, extension: ext)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: temporaryURL, to: destination)

                let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                let record = DownloadRecord(
                    songID: track.id,
                    name: track.name,
                    artist: track.artistText,
                    albumName: track.album?.name ?? "",
                    coverURL: track.album?.picUrl ?? "",
                    durationMs: track.durationMs,
                    quality: quality.title,
                    fileExtension: ext,
                    fileSize: size,
                    createdAt: Date()
                )
                records.removeAll { $0.songID == track.id }
                records.insert(record, at: 0)
                save()
            } catch {
                lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func remove(_ record: DownloadRecord) {
        if let url = DownloadStore.findFile(id: record.songID) {
            try? FileManager.default.removeItem(at: url)
        }
        records.removeAll { $0.songID == record.songID }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([DownloadRecord].self, from: data) else {
            return
        }
        records = decoded.filter { DownloadStore.findFile(id: $0.songID) != nil }
    }
}