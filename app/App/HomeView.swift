import SwiftUI
import AVKit
import AyatDesign
import AyatContent

/// Ayah of the day: one of the site's common-ayat shortcuts (clip maker and card tool:
/// Al-Fatiha, Ayat al-Kursi, end of Al-Baqarah, Ash-Sharh 5–6, Al-Ikhlas, Al-Mulk, Ar-Ra'd 28),
/// rotating by day. Text comes from the content pack.
enum AyahOfTheDay {
    struct Pick: Equatable { let surah: Int; let from: Int; let to: Int }

    static let picks: [Pick] = [
        .init(surah: 1, from: 1, to: 7), .init(surah: 2, from: 255, to: 255), .init(surah: 2, from: 285, to: 286),
        .init(surah: 94, from: 5, to: 6), .init(surah: 112, from: 1, to: 4), .init(surah: 67, from: 1, to: 1),
        .init(surah: 13, from: 28, to: 28),
    ]

    static func pick(for date: Date = Date()) -> Pick {
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .era, for: date) ?? 0
        return picks[day % picks.count]
    }

    static func reference(_ p: Pick) -> String {
        let name = ContentLibrary.shared.surah(p.surah)?.shortName ?? ""
        return p.from == p.to ? "\(name) · \(Num.int(p.from))" : "\(name) · \(Num.int(p.from))–\(Num.int(p.to))"
    }
}

/// Home, per design/Main.dc.html.
struct HomeView: View {
    @AppStorage("quran.lastPage") private var lastPage = 0
    @AppStorage(Favorites.key) private var favorites = ""
    private let lib = ContentLibrary.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Num.hijri(Date())).font(.subheadline).foregroundStyle(Brand.muted)
                if lib.isReady { ayahCard }
                createRow
                NextPrayerCard()
                if lib.isReady { continueReading }
                projects
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("آيات تتلى")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("الإعدادات")
            }
        }
    }

    private var ayahCard: some View {
        let p = AyahOfTheDay.pick()
        let ayat = (try? lib.store?.ayat(surah: p.surah, from: p.from, to: p.to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let first = RecitationPlayer.Position(surah: p.surah, ayah: p.from)
        let isFav = Favorites.list(favorites).contains(first)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("آية اليوم").font(.subheadline.weight(.semibold))
                Spacer()
                Text(AyahOfTheDay.reference(p)).font(.footnote).opacity(0.9)
            }
            Text(text)
                .font(.custom(ContentLibrary.mushafFont, size: 22, relativeTo: .title3))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(8)
            HStack(spacing: 10) {
                NavigationLink { MushafReader(startPage: ayat.first?.page ?? 1, focus: first) } label: {
                    Label("اقرأ في المصحف", systemImage: "book")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                Spacer()
                ShareLink(item: "﴿\(text)﴾ [\(AyahOfTheDay.reference(p))]") {
                    Image(systemName: "square.and.arrow.up").frame(width: Brand.minTap, height: Brand.minTap)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
                .accessibilityLabel("مشاركة")
                Button { favorites = Favorites.toggled(favorites, first) } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart").frame(width: Brand.minTap, height: Brand.minTap)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
                .accessibilityLabel(isFav ? "أزل من المفضلة" : "أضف للمفضلة")
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(LinearGradient(colors: [Brand.g0, Brand.primary], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var createRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("اصنع").font(.headline)
            HStack(spacing: 10) {
                createTile("مقطع", "play.rectangle")
                createTile("بطاقة", "rectangle.portrait")
                createTile("حالة", "text.bubble")
                createTile("إهداء", "gift")
            }
        }
    }

    /// Only the card editor is built; the other tiles open the placeholder until the video engine lands.
    private func createTile(_ title: String, _ symbol: String) -> some View {
        NavigationLink {
            switch title {
            case "بطاقة": AyahCardView()
            case "مقطع": ClipMakerView()
            case "حالة": StatusSourceView()
            default: AyahCardView(surah: 2, from: 201, templateID: "ihdaa")
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Brand.primary)
                    .frame(width: 40, height: 40).background(Brand.tint, in: RoundedRectangle(cornerRadius: 12))
                Text(title).font(.footnote).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .card()
        }
        .buttonStyle(.plain)
        
    }

    private var continueReading: some View {
        let page = max(lastPage, 1)
        let first = (try? lib.store?.page(page))?.first
        let name = first.flatMap { lib.surah($0.surah)?.shortName } ?? ""
        return NavigationLink { MushafReader(startPage: page) } label: {
            HStack(spacing: 14) {
                Image(systemName: "book").font(.title3).foregroundStyle(Brand.primary)
                    .frame(width: 44, height: 44).background(Brand.tint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) {
                    Text(lastPage > 0 ? "تابع القراءة" : "ابدأ القراءة").font(.headline).foregroundStyle(.primary)
                    Text("\(name) · صفحة \(Num.int(page))").font(.footnote).foregroundStyle(Brand.muted)
                    ProgressView(value: Double(page), total: Double(max(lib.pageCount, 1))).tint(Brand.primary)
                }
            }
            .padding(16)
            .card()
        }
        .buttonStyle(.plain)
    }

    private var projects: some View {
        let recent = Array(ProjectStore.shared.projects.prefix(6))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("آخر المشاريع").font(.headline)
                Spacer()
                if !recent.isEmpty {
                    NavigationLink("عرض الكل") { LibraryView(initial: .projects) }.font(.subheadline)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recent) { p in
                        NavigationLink { ProjectDetailView(project: p) } label: { ProjectTile(project: p, width: 104) }
                            .buttonStyle(.plain)
                    }
                    NavigationLink { StudioView() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title3)
                            Text("مشروع جديد").font(.caption)
                        }
                        .foregroundStyle(Brand.primaryInk)
                        .frame(width: 104, height: 148)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5])).foregroundStyle(Brand.line))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Library, per design/Library.dc.html. Projects, downloads and plans fill in as the studio,
/// offline audio and khatma are built; favorites work now.
struct LibraryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case projects, favorites, downloads, plans
        var id: String { rawValue }
        var title: String {
            switch self {
            case .projects: "المشاريع"
            case .favorites: "المفضلة"
            case .downloads: "التنزيلات"
            case .plans: "الخطط"
            }
        }
    }

    @AppStorage(Favorites.key) private var favorites = ""
    @State private var section: Section
    private let lib = ContentLibrary.shared

    init(initial: Section = .favorites) { _section = State(initialValue: initial) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("أقسام المكتبة", selection: $section) {
                ForEach(Section.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 8)
            switch section {
            case .favorites: favoritesList
            case .projects: ProjectsGrid()
            case .downloads:
                ContentUnavailableView("لا تنزيلات", systemImage: "arrow.down.circle",
                                       description: Text("حفظ التلاوات للاستماع دون إنترنت يتاح بعد إذن مصدر التلاوات"))
            case .plans:
                List {
                    NavigationLink { KhatmaView() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("خطة الختمة").font(.headline)
                                Text(khatmaLine).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "calendar").foregroundStyle(Brand.primary) }
                        .frame(minHeight: Brand.minTap)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("مكتبتي")
    }

    @AppStorage(KhatmaStore.key) private var khatmaRaw = ""

    private var khatmaLine: String {
        guard let p = KhatmaStore.load(khatmaRaw) else { return "وزع الختمة على الأيام والصلوات" }
        let d = min(max(p.day(on: Date()), 1), p.days)
        guard let r = p.range(day: d) else { return "اليوم \(Num.int(d)) من \(Num.int(p.days))" }
        return "اليوم \(Num.int(d)) من \(Num.int(p.days)) · ورد اليوم: صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound))"
    }

    @ViewBuilder private var favoritesList: some View {
        let items = Favorites.list(favorites)
        if items.isEmpty {
            ContentUnavailableView("لا آيات في المفضلة", systemImage: "heart",
                                   description: Text("اضغط على أي آية في المصحف ثم «أضف للمفضلة»"))
        } else {
            List {
                ForEach(items) { p in
                    let a = (try? lib.store?.ayat(surah: p.surah, from: p.ayah, to: p.ayah))?.first
                    NavigationLink { MushafReader(startPage: a?.page ?? 1, focus: p) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(QuranText.reference(p)).font(.caption).foregroundStyle(Brand.primaryInk)
                            Text(a?.textUthmani ?? "").font(.custom(ContentLibrary.mushafFont, size: 19, relativeTo: .body))
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { idx in
                    for i in idx { favorites = Favorites.toggled(favorites, items[i]) }
                }
            }
        }
    }
}

// MARK: - Projects

struct ProjectTile: View {
    let project: Project
    var width: CGFloat = 104

    var body: some View {
        let ratio = CardOptions.Ratio(rawValue: project.ratio) ?? .square
        let h = min(width * ratio.size.height / ratio.size.width, width * 1.6)
        ZStack(alignment: .bottomLeading) {
            if let img = UIImage(contentsOfFile: ProjectStore.shared.thumbnailURL(project).path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Brand.g0, Brand.primary], startPoint: .top, endPoint: .bottom)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                if project.kind == .clip { Image(systemName: "play.fill").font(.caption2) }
                Text(project.subtitle).font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(8)
        }
        .frame(width: width, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(project.title)، \(project.subtitle)")
    }
}

struct ProjectsGrid: View {
    private var store = ProjectStore.shared

    var body: some View {
        if store.projects.isEmpty {
            ContentUnavailableView("لا مشاريع بعد", systemImage: "play.rectangle",
                                   description: Text("ما تصنعه في الاستوديو يحفظ هنا على جهازك"))
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                    ForEach(store.projects) { p in
                        NavigationLink { ProjectDetailView(project: p) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                ProjectTile(project: p, width: 104)
                                Text(p.title).font(.caption).lineLimit(1)
                                Text(p.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Num.locale)))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

struct ProjectDetailView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var saved = false

    var body: some View {
        let url = ProjectStore.shared.url(project)
        let ratio = CardOptions.Ratio(rawValue: project.ratio) ?? .square
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    if project.kind == .clip {
                        VideoPlayer(player: AVPlayer(url: url))
                    } else if let img = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: img).resizable()
                    }
                }
                .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
                .frame(maxHeight: 560)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("\(project.subtitle) · \(project.createdAt.formatted(Date.FormatStyle(date: .long, time: .shortened, locale: Num.locale)))")
                    .font(.footnote).foregroundStyle(Brand.muted)
                HStack(spacing: 10) {
                    ShareLink(item: url) { Label("مشاركة", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
                        .buttonStyle(.borderedProminent)
                    Button {
                        if project.kind == .clip { UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil) }
                        else if let img = UIImage(contentsOfFile: url.path) { UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil) }
                        saved = true
                    } label: { Label("حفظ في الصور", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
                    .buttonStyle(.bordered)
                }
                if let e = project.settings {
                    NavigationLink {
                        if project.kind == .clip { ClipMakerView(settings: e) } else { AyahCardView(settings: e) }
                    } label: { Label("تعديل بنفس الإعدادات", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
                    .buttonStyle(.bordered)
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("حذف المشروع", systemImage: "trash").frame(maxWidth: .infinity, minHeight: Brand.minTap)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("حذف المشروع من مكتبتي؟", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("حذف", role: .destructive) { ProjectStore.shared.delete(project); dismiss() }
        }
        .alert("حفظ في الصور", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
    }
}
