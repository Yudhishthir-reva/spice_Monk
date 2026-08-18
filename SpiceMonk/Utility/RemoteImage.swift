//
//  RemoteImage.swift
//  SpiceMonk
//

import SwiftUI

/// Downloads are owned here rather than by the views that display them. A paged `TabView` or a lazy
/// row recycles its children constantly, and a download tied to a child dies with it — which is why
/// `AsyncImage` left the hero banner on a broken-image icon: it treats that cancellation as a
/// permanent failure and never retries. Keeping the task and the decoded result outside the view
/// means recycling costs nothing and a second look is served from memory.
/// `NSCache` is already thread-safe, so decoded images live outside the actor's isolation. That lets
/// a view answer a cache hit synchronously while in-flight downloads stay serialised on the actor.
private nonisolated final class DecodedImageCache: @unchecked Sendable {

    private let storage = NSCache<NSURL, UIImage>()

    init(countLimit: Int) {
        storage.countLimit = countLimit
    }

    func image(for url: URL) -> UIImage? {
        storage.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        storage.setObject(image, forKey: url as NSURL)
    }
}

actor ImageLoader {

    static let shared = ImageLoader()

    private nonisolated let cache = DecodedImageCache(countLimit: 200)
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    private init() {}

    nonisolated func cached(_ url: URL) -> UIImage? {
        cache.image(for: url)
    }

    func image(for url: URL) async throws -> UIImage {
        if let hit = cache.image(for: url) {
            return hit
        }

        // Several cards can ask for the same URL at once; they share one download.
        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode),
                let image = UIImage(data: data)
            else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }
        inFlight[url] = task

        // `result` waits for the download even if this particular caller went away, so a scrolled-off
        // card still warms the cache for the next view that needs it.
        let result = await task.result
        inFlight[url] = nil

        if case .success(let image) = result {
            cache.insert(image, for: url)
        }
        return try result.get()
    }
}

struct RemoteImage: View {

    let url: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    private var resolvedURL: URL? {
        guard let url, !url.isEmptyString else { return nil }
        return URL(string: url.trim)
    }

    var body: some View {
        content
            .task(id: resolvedURL) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            imagePlaceholder
        }
    }

    /// Shown while loading, when the URL is missing, and when the download fails — so list tiles
    /// never sit empty.
    private var imagePlaceholder: some View {
        ZStack {
            AppTheme.imageTile
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.62, height: side * 0.62)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func load() async {
        guard let resolvedURL else {
            image = nil
            return
        }

        // A cache hit is shown without a placeholder frame in between, so recycled rows don't flash.
        if let hit = ImageLoader.shared.cached(resolvedURL) {
            image = hit
            return
        }

        do {
            image = try await ImageLoader.shared.image(for: resolvedURL)
        } catch {
            // Being recycled is not a failed image; leave the placeholder so the retry on reappear
            // can still succeed.
            if !Task.isCancelled {
                image = nil
            }
        }
    }
}
