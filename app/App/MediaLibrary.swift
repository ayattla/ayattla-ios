import SwiftUI
import AVFoundation
import CoreImage
import AyatDesign

/// Real photos and videos (Pixabay, Pexels) through ayattla.com's media endpoints: the same
/// background library the site's editors open. No provider keys live in the app: the site's server
/// does the provider calls. As on the site (bg-library.js), nothing permanent keeps provider file
/// links: favorites keep {provider, mediaId, type} only, previews are shown straight from the
/// provider, and the full file is fetched through /api/media/raw only when a card or clip is made.
/// The photographer's name is not shown (owner rule); the provider name is.
enum MediaLibrary {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case image, video
        var id: String { rawValue }
        var title: String { self == .image ? "صور" : "فيديو" }
    }

    struct Item: Decodable, Identifiable, Hashable {
        let provider: String
        let mediaId: String
        let type: Kind
        let thumbUrl: URL?
        let previewUrl: URL?
        let width: Int?
        let height: Int?
        let duration: Double?
        let curated: Bool

        var id: String { ref.key }
        var ref: Ref { Ref(provider: provider, mediaId: mediaId, type: type) }
        var providerName: String { MediaLibrary.providerName(provider) }
        var isPortrait: Bool { (height ?? 1) >= (width ?? 1) }

        enum CodingKeys: String, CodingKey { case provider, mediaId, type, thumbUrl, previewUrl, width, height, duration, curated }

        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            provider = try c.decode(String.self, forKey: .provider)
            if let s = try? c.decode(String.self, forKey: .mediaId) { mediaId = s } else { mediaId = String(try c.decode(Int.self, forKey: .mediaId)) }
            type = (try? c.decode(Kind.self, forKey: .type)) ?? .image
            thumbUrl = (try? c.decode(String.self, forKey: .thumbUrl)).flatMap(URL.init(string:))
            previewUrl = (try? c.decode(String.self, forKey: .previewUrl)).flatMap(URL.init(string:))
            width = try? c.decode(Int.self, forKey: .width)
            height = try? c.decode(Int.self, forKey: .height)
            duration = (try? c.decode(Double.self, forKey: .duration)) ?? (try? c.decode(Int.self, forKey: .duration)).map(Double.init)
            curated = (try? c.decode(Bool.self, forKey: .curated)) ?? false
        }
    }

    /// What may be stored: the provider, the provider's id and the type, nothing else.
    struct Ref: Codable, Hashable {
        let provider: String
        let mediaId: String
        let type: Kind
        var key: String { "\(provider):\(mediaId):\(type.rawValue)" }
        init(provider: String, mediaId: String, type: Kind) { self.provider = provider; self.mediaId = mediaId; self.type = type }
        init?(key: String) {
            let p = key.split(separator: ":").map(String.init)
            guard p.count == 3, let k = Kind(rawValue: p[2]) else { return nil }
            self.init(provider: p[0], mediaId: p[1], type: k)
        }
    }

    struct Collection: Decodable, Hashable, Identifiable {
        let id: String
        let label: String
        enum CodingKeys: String, CodingKey { case id, label, name, title }
        init(id: String, label: String) { self.id = id; self.label = label }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            label = (try? c.decode(String.self, forKey: .label)) ?? (try? c.decode(String.self, forKey: .name))
                ?? (try? c.decode(String.self, forKey: .title)) ?? id
        }
    }

    private struct Page: Decodable { let items: [Item] }
    private struct Collections: Decodable { let collections: [Collection] }

    static let base = URL(string: "https://ayattla.com/api/media/")!

    /// Shown until /api/media/collections answers (the ids the site's own pages ask for).
    static let fallbackCollections: [Collection] = [
        ("sky", "سماء"), ("sea", "بحر"), ("mountains", "جبال"), ("rain", "مطر"), ("night", "ليل"), ("desert", "صحراء"),
        ("nature", "طبيعة"), ("sunset", "غروب"), ("mosques", "مساجد"), ("light", "ضوء"), ("water", "ماء"),
    ].map { Collection(id: $0.0, label: $0.1) }   // /api/media/collections on 2026-11-04

    static func providerName(_ p: String) -> String {
        switch p { case "pexels": "Pexels"; case "pixabay": "Pixabay"; default: p }
    }

    // MARK: Requests

    /// GET /api/media/search?type=&q=&category=&page=&orientation=  (as bg-library.js; page ≤ 10)
    static func search(_ kind: Kind, category: String, query: String = "", page: Int = 1,
                       orientation: String = "portrait") async throws -> [Item] {
        var c = URLComponents(url: base.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "type", value: kind.rawValue), .init(name: "q", value: query),
                        .init(name: "category", value: query.isEmpty ? category : ""),
                        .init(name: "page", value: String(min(max(page, 1), 10))),
                        .init(name: "orientation", value: orientation)]
        guard let url = c.url else { throw URLError(.badURL) }
        let data = try await get(url)
        return try JSONDecoder().decode(Page.self, from: data).items.filter { !$0.mediaId.isEmpty }
    }

    /// GET /api/media/collections (the chips on the site's library).
    static func collections() async -> [Collection] {
        guard let data = try? await get(base.appendingPathComponent("collections")),
              let list = try? JSONDecoder().decode(Collections.self, from: data).collections, !list.isEmpty
        else { return fallbackCollections }
        return list
    }

    /// GET /api/media/item?provider=&id=&type=  (turns a favorite back into an item with fresh previews).
    static func item(_ ref: Ref) async throws -> Item {
        var c = URLComponents(url: base.appendingPathComponent("item"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "provider", value: ref.provider), .init(name: "id", value: ref.mediaId),
                        .init(name: "type", value: ref.type.rawValue)]
        guard let url = c.url else { throw URLError(.badURL) }
        return try JSONDecoder().decode(Item.self, from: try await get(url))
    }

    /// /api/media/raw?rm=provider:id:type&w=  (the full file, fetched by the site's server).
    static func rawURL(_ ref: Ref, width: Int) -> URL {
        var c = URLComponents(url: base.appendingPathComponent("raw"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "rm", value: ref.key), .init(name: "w", value: String(width))]
        // Query items are percent-encoded by URLComponents; the fallback keeps a bad key from crashing.
        return c.url ?? base.appendingPathComponent("raw")
    }

    /// Full photo for a card or a clip (1080 px wide, as the site), kept in memory only.
    static func image(_ item: Item) async throws -> UIImage {
        let data = try await get(rawURL(item.ref, width: 1080), timeout: 60)
        if let img = UIImage(data: data) { return img.uprightForVideo() }
        // The preview is good enough when the full file cannot be decoded.
        if let p = item.previewUrl, let img = UIImage(data: try await get(p, timeout: 30)) { return img.uprightForVideo() }
        throw URLError(.cannotDecodeContentData)
    }

    /// Full photo from a stored reference (home gallery, saved projects).
    static func image(_ ref: Ref) async throws -> UIImage {
        guard let img = UIImage(data: try await get(rawURL(ref, width: 1080), timeout: 60)) else { throw URLError(.cannotDecodeContentData) }
        return img.uprightForVideo()
    }

    /// Full video for a clip (540 px wide, as the site), written to a temporary file that the
    /// clip export deletes when it is done.
    static func video(_ item: Item) async throws -> URL {
        let (tmp, resp) = try await URLSession.shared.download(for: request(rawURL(item.ref, width: 540), timeout: 120))
        guard let h = resp as? HTTPURLResponse, h.statusCode == 200 else { throw URLError(.badServerResponse) }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("bg-\(item.provider)-\(item.mediaId).mp4")
        try? FileManager.default.removeItem(at: out)
        try FileManager.default.moveItem(at: tmp, to: out)
        return out
    }

    private static func request(_ url: URL, timeout: TimeInterval) -> URLRequest {
        var r = URLRequest(url: url)
        r.timeoutInterval = timeout
        r.setValue("AyatTutla-iOS", forHTTPHeaderField: "User-Agent")
        return r
    }

    private static func get(_ url: URL, timeout: TimeInterval = 20) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(for: request(url, timeout: timeout))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    // MARK: Favorites ({provider, mediaId, type} only, at most 60, as the site)

    static let favoritesKey = "ayt_bg_favs"
    static var favorites: [Ref] {
        get { (UserDefaults.standard.array(forKey: favoritesKey) as? [String] ?? []).compactMap(Ref.init(key:)) }
        set { UserDefaults.standard.set(Array(newValue.prefix(60)).map(\.key), forKey: favoritesKey) }
    }
    static func isFavorite(_ r: Ref) -> Bool { favorites.contains(r) }
    static func toggleFavorite(_ r: Ref) {
        var f = favorites
        if let i = f.firstIndex(of: r) { f.remove(at: i) } else { f.insert(r, at: 0) }
        favorites = f
    }

    static func durationText(_ s: Double?) -> String? {
        guard let s, s > 0 else { return nil }
        let t = Int(s.rounded())
        return "\u{2066}\(Num.int(t / 60)):\(t % 60 < 10 ? Num.int(0) : "")\(Num.int(t % 60))\u{2069}"
    }
}

// MARK: - Picking

/// What an editor got from the library: the item and the loaded file.
enum PickedMedia {
    case image(MediaLibrary.Item, UIImage)
    case video(MediaLibrary.Item, URL, poster: UIImage?)
}

/// The site's «مكتبة الخلفيات» as a sheet: photos or videos, collections, search, favorites,
/// real thumbnails in a 2-column grid (4 on iPad), loading, empty and error states.
struct MediaLibrarySheet: View {
    let kinds: [MediaLibrary.Kind]
    let onPick: (PickedMedia) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var kind: MediaLibrary.Kind
    @State private var collections = MediaLibrary.fallbackCollections
    @State private var collection = "sky"
    @State private var query = ""
    @State private var submitted = ""
    @State private var items: [MediaLibrary.Item] = []
    @State private var page = 1
    @State private var loading = false
    @State private var failed = false
    @State private var done = false
    @State private var fetching: String?
    @State private var pickFailed = false
    @State private var favs = MediaLibrary.favorites

    static let favID = "__fav"

    init(kinds: [MediaLibrary.Kind] = [.image], initial: MediaLibrary.Kind? = nil, onPick: @escaping (PickedMedia) -> Void) {
        self.kinds = kinds; self.onPick = onPick
        _kind = State(initialValue: initial ?? kinds.first ?? .image)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    if kinds.count > 1 {
                        SiteSegmented(kinds.map { (id: $0, title: $0.title, detail: String?.none) }, selection: $kind)
                            .padding(.horizontal, 16)
                    }
                    searchField.padding(.horizontal, 16)
                    CategorySelector(chips, selection: $collection)
                    grid.padding(.horizontal, 16)
                    Text("الصور والمقاطع من Pixabay وPexels عبر موقع آيات تتلى. تعرض المعاينة مؤقتا، والملف الكامل يجلب عند الاستخدام فقط.")
                        .font(.ui(.caption)).foregroundStyle(Brand.muted)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        .padding(.horizontal, 24).padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .background(Brand.background)
            .navigationTitle("مكتبة الخلفيات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } } }
            .overlay { if fetching != nil { fetchingOverlay } }
            .alert("تعذر جلب الملف، حاول مرة أخرى", isPresented: $pickFailed) { Button("حسنا", role: .cancel) {} }
        }
        .task { collections = await MediaLibrary.collections(); if !collections.contains(where: { $0.id == collection }) { collection = collections.first?.id ?? "sky" } }
        .task(id: "\(kind.rawValue)|\(collection)|\(submitted)") { await reload() }
    }

    private var chips: [(id: String, title: String)] {
        [(id: Self.favID, title: "المفضلة")] + collections.map { (id: $0.id, title: $0.label) }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Brand.muted)
            TextField("ابحث: سماء، بحر، مطر…", text: $query)
                .font(.ui(.subheadline)).submitLabel(.search)
                .onSubmit { submitted = query.trimmingCharacters(in: .whitespaces) }
            if !query.isEmpty {
                Button { query = ""; submitted = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.muted) }
                    .accessibilityLabel("مسح البحث")
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
    }

    @ViewBuilder private var grid: some View {
        if items.isEmpty && loading {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Brand.surface2)
                        .aspectRatio(3 / 4, contentMode: .fit)
                }
            }
            .accessibilityLabel("جار التحميل")
        } else if items.isEmpty && failed {
            ErrorState(retry: { Task { await reload() } }).frame(minHeight: 260)
        } else if items.isEmpty {
            EmptyState(collection == Self.favID ? "لا توجد مفضلة بعد" : "لا توجد نتائج", symbol: collection == Self.favID ? "heart" : "photo",
                       message: collection == Self.favID ? "اضغط القلب على أي خلفية لحفظها هنا" : "جرب كلمة أخرى أو مجموعة أخرى")
                .frame(minHeight: 260)
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { it in
                    MediaTile(item: it, favorite: favs.contains(it.ref), busy: fetching == it.id) {
                        pick(it)
                    } toggleFavorite: {
                        MediaLibrary.toggleFavorite(it.ref); favs = MediaLibrary.favorites
                    }
                    .onAppear { if it.id == items.last?.id { Task { await more() } } }
                }
            }
            if loading { ProgressView().tint(Brand.primaryInk).frame(maxWidth: .infinity).padding() }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: hSize == .regular ? 4 : 2)
    }

    private var fetchingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white)
            Text(kind == .video ? "جار تجهيز المقطع" : "جار تجهيز الصورة").font(.ui(.footnote, .semibold)).foregroundStyle(.white)
        }
        .padding(22).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func reload() async {
        items = []; page = 1; done = false
        await load()
    }

    private func more() async {
        guard !loading, !done, collection != Self.favID, page < 10 else { return }
        page += 1
        await load()
    }

    private func load() async {
        loading = true; failed = false
        defer { loading = false }
        do {
            if collection == Self.favID {
                var out: [MediaLibrary.Item] = []
                for r in MediaLibrary.favorites where r.type == kind {
                    if let it = try? await MediaLibrary.item(r) { out.append(it) }
                }
                items = out; done = true
            } else {
                let got = try await MediaLibrary.search(kind, category: collection, query: submitted, page: page)
                let known = Set(items.map(\.id))
                items += got.filter { !known.contains($0.id) }
                if got.isEmpty { done = true }
            }
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private func pick(_ it: MediaLibrary.Item) {
        guard fetching == nil else { return }
        fetching = it.id
        Task {
            defer { fetching = nil }
            do {
                switch it.type {
                case .image:
                    let img = try await MediaLibrary.image(it)
                    onPick(.image(it, img))
                case .video:
                    let url = try await MediaLibrary.video(it)
                    var poster: UIImage?
                    if let t = it.thumbUrl, let d = try? await URLSession.shared.data(from: t).0 { poster = UIImage(data: d) }
                    if poster == nil { poster = await VideoFrames.poster(url) }
                    onPick(.video(it, url, poster: poster))
                }
                dismiss()
            } catch { pickFailed = true }
        }
    }
}

/// One library item: the provider's thumbnail, a video badge with the length, a favorite heart.
struct MediaTile: View {
    let item: MediaLibrary.Item
    var favorite = false
    var busy = false
    var selected = false
    let pick: () -> Void
    var toggleFavorite: (() -> Void)? = nil

    var body: some View {
        Button(action: pick) {
            Brand.surface2
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { MediaThumb(url: item.thumbUrl) }
                .overlay(alignment: .topLeading) {
                    if item.type == .video {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 9))
                            if let d = MediaLibrary.durationText(item.duration) { Text(d) }
                        }
                        .font(.ui(.caption2, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: 0x0B1F17).opacity(0.75), in: Capsule())
                        .padding(8)
                    }
                }
                .overlay { if busy { Color.black.opacity(0.35); ProgressView().tint(.white) } }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Brand.green : Brand.line, lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.pressable)
        .overlay(alignment: .topTrailing) {
            if let toggleFavorite {
                Button(action: toggleFavorite) {
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(favorite ? .white : Brand.primaryInk)
                        .frame(width: 34, height: 34)
                        .background(favorite ? AnyShapeStyle(Brand.primaryInk) : AnyShapeStyle(Color.white.opacity(0.9)), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .frame(minWidth: Brand.minTap, minHeight: Brand.minTap, alignment: .topTrailing)
                .accessibilityLabel(favorite ? "إزالة من المفضلة" : "إضافة إلى المفضلة")
            }
        }
        .accessibilityLabel(item.type == .video ? "مقطع خلفية من \(item.providerName)" : "صورة خلفية من \(item.providerName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Provider thumbnail with a mint placeholder while it loads and an icon when it fails.
struct MediaThumb: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let img): img.resizable().scaledToFill()
            // Transparent while loading or on failure, so the tile colour behind shows.
            default: Color.clear
            }
        }
    }
}

/// Muted looping preview of a provider video (the site plays `previewUrl` the same way).
struct LoopingVideo: UIViewRepresentable {
    let url: URL

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var looper: AVPlayerLooper?
        var current: URL?

        /// Plays only while on screen: a pushed screen or another tab no longer keeps decoding
        /// the preview in the background.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { playerLayer.player?.pause() } else { playerLayer.player?.play() }
        }
    }

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.videoGravity = .resizeAspectFill
        v.isUserInteractionEnabled = false
        set(url, on: v)
        return v
    }

    func updateUIView(_ v: PlayerView, context: Context) { if v.current != url { set(url, on: v) } }

    private func set(_ url: URL, on v: PlayerView) {
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        v.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        v.playerLayer.player = player
        v.current = url
        player.play()
    }

    static func dismantleUIView(_ v: PlayerView, coordinator: ()) { v.playerLayer.player?.pause(); v.looper = nil }
}

// MARK: - Video frames for clip export

/// Reads a background video frame by frame for the clip export, looping it when the clip is longer.
/// Frames are asked for in increasing time; each call returns the frame on screen at `t`.
final class VideoFrames {
    private let asset: AVURLAsset
    private let track: AVAssetTrack
    private let duration: Double
    private var reader: AVAssetReader?
    private var output: AVAssetReaderTrackOutput?
    private var loop = 0
    private var last: CGImage?
    private var pending: (t: Double, image: CGImage)?

    init?(url: URL) async {
        asset = AVURLAsset(url: url)
        guard let t = try? await asset.loadTracks(withMediaType: .video).first,
              let d = try? await asset.load(.duration), d.seconds > 0.2 else { return nil }
        track = t; duration = d.seconds
        guard start() else { return nil }
    }

    private func start() -> Bool {
        guard let r = try? AVAssetReader(asset: asset) else { return false }
        let o = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        o.alwaysCopiesSampleData = false
        guard r.canAdd(o) else { return false }
        r.add(o)
        guard r.startReading() else { return false }
        reader = r; output = o
        return true
    }

    private func nextSample() -> (t: Double, image: CGImage)? {
        if let p = pending { pending = nil; return p }
        for _ in 0..<2 {
            if let s = output?.copyNextSampleBuffer(), let pb = CMSampleBufferGetImageBuffer(s) {
                let t = CMSampleBufferGetPresentationTimeStamp(s).seconds + Double(loop) * duration
                let ci = CIImage(cvPixelBuffer: pb)
                if let cg = Self.ciContext.createCGImage(ci, from: ci.extent) { return (t, cg) }
                continue
            }
            loop += 1                     // end of the file: start it again
            reader?.cancelReading()
            guard start() else { return nil }
        }
        return nil
    }

    /// The frame showing at time `t` (seconds from the clip start).
    func frame(at t: Double) -> CGImage? {
        while let s = nextSample() {
            if s.t > t + 0.0001 { pending = s; break }
            last = s.image
        }
        if last == nil, let p = pending { last = p.image }
        return last
    }

    func close() { reader?.cancelReading() }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// A still from the middle of the video for previews.
    static func poster(_ url: URL) async -> UIImage? {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.maximumSize = CGSize(width: 720, height: 720)
        guard let cg = try? await g.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image else { return nil }
        return UIImage(cgImage: cg)
    }
}
