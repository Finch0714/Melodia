import CryptoKit
import Foundation
import SwiftUI
import UIKit

extension URL {
    func melodiaImageURL(pixels: Int) -> URL {
        guard let host = host?.lowercased(),
              host.contains("126.net") || host.contains("127.net") else {
            return self
        }
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var queryItems = components.queryItems ?? []
        guard !queryItems.contains(where: { $0.name == "param" }) else { return self }
        let side = min(max(pixels, 64), 1024)
        queryItems.append(URLQueryItem(name: "param", value: "\(side)y\(side)"))
        components.queryItems = queryItems
        return components.url ?? self
    }
}

actor RemoteImageCache {
    static let shared = RemoteImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private var tasks: [URL: Task<UIImage?, Never>] = [:]
    private let diskDirectory: URL?

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()

    init() {
        memory.countLimit = 320
        memory.totalCostLimit = 120 * 1024 * 1024
        diskDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MelodiaImages", isDirectory: true)
    }

    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func clear() {
        memory.removeAllObjects()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        Self.session.configuration.urlCache?.removeAllCachedResponses()
        guard let diskDirectory else { return }
        try? FileManager.default.removeItem(at: diskDirectory)
    }

    func diskSize() -> Int64 {
        guard let diskDirectory,
              let enumerator = FileManager.default.enumerator(
                at: diskDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSURL) {
            return cached
        }
        if let existing = tasks[url] {
            return await existing.value
        }

        let directory = diskDirectory
        let task = Task.detached(priority: .userInitiated) {
            Self.loadImage(url: url, directory: directory)
        }
        tasks[url] = task
        let image = await task.value
        tasks[url] = nil

        if let image {
            let pixels = image.size.width * image.size.height * image.scale * image.scale
            memory.setObject(image, forKey: url as NSURL, cost: Int(pixels * 4))
        }
        return image
    }

    private static func loadImage(url: URL, directory: URL?) -> UIImage? {
        let fileURL = directory.map { cacheFile(for: url, in: $0) }

        if let fileURL,
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            return nil
        }

        if let directory, let fileURL {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try? data.write(to: fileURL, options: .atomic)
        }
        return image
    }

    private static func cacheFile(for url: URL, in directory: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            if let cached = await RemoteImageCache.shared.cachedImage(for: url) {
                guard !Task.isCancelled else { return }
                image = cached
                return
            }
            let loaded = await RemoteImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}