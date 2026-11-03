import SwiftUI
import AVKit
import AyatDesign
import AyatContent

/// Ayah of the day (picks shared with the widget: AyatContent.DailyAyah).
enum AyahOfTheDay {
    typealias Pick = DailyAyah.Pick
    static var picks: [Pick] { DailyAyah.picks }
    static func pick(for date: Date = Date()) -> Pick { DailyAyah.pick(for: date) }

    static func reference(_ p: Pick) -> String {
        let name = ContentLibrary.shared.surah(p.surah)?.shortName ?? ""
        return p.from == p.to ? "\(name) · \(Num.int(p.from))" : "\(name) · \(Num.int(p.from))–\(Num.int(p.to))"
    }
}

/// Home: the site's home page in its order (design/Main.dc.html, docs/SITE_AUDIT.md §2).
struct HomeView: View {
    @AppStorage("quran.lastPage") private var lastPage = 0
    @AppStorage(Favorites.key) private var favorites = ""
    private let lib = ContentLibrary.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                // Site order (docs/SITE_AUDIT.md §2), with the app's daily cards after the products.
                header
                if lib.isReady { ayahCard }
                HomeProducts()
                PresetStrip()
                HomeSources()
                NextPrayerCard()
                if lib.isReady { continueReading }
                RecentProjectsStrip()
                HomeSteps()
                HomeFeatures()
                toolGroups
                HomeStats()
                HomeFAQ()
                HomeClosing()
                footer
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("آيات تتلى")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("LogoHorizontal").resizable().scaledToFit().frame(height: 30)
                    .accessibilityLabel("آيات تتلى")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("الإعدادات")
            }
        }
    }

    /// Greeting line under the bar: hijri date and the site's tagline.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Num.hijri(Date())).font(.ui(.subheadline, .medium)).foregroundStyle(Brand.goldInk)
            Text("اصنع مقطعك القرآني، واقرأ وردك، وأذكارك معك").font(.ui(.title3, .semibold)).foregroundStyle(Brand.ink)
        }
    }

    private var ayahCard: some View {
        let p = AyahOfTheDay.pick()
        let ayat = (try? lib.store?.ayat(surah: p.surah, from: p.from, to: p.to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let first = RecitationPlayer.Position(surah: p.surah, ayah: p.from)
        let isFav = Favorites.list(favorites).contains(first)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                StarOrnament().frame(width: 18, height: 18)
                Text("آية اليوم").font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.onDeepAccent)
                Spacer()
                Text(AyahOfTheDay.reference(p)).font(.ui(.footnote, .medium)).foregroundStyle(Brand.onDeepAccent.opacity(0.9))
            }
            Text(text)
                .font(.custom(ContentLibrary.mushafFont, size: 23, relativeTo: .title3))
                .lineSpacing(10)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(8)
            HStack(spacing: 10) {
                NavigationLink { MushafReader(startPage: ayat.first?.page ?? 1, focus: first) } label: {
                    Label("اقرأ في المصحف", systemImage: "book")
                        .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.primary)
                        .padding(.horizontal, 16).frame(minHeight: Brand.minTap)
                        .background(Brand.accent, in: Capsule())
                }
                NavigationLink { ClipMakerView(surah: p.surah, from: p.from, to: p.to) } label: {
                    Label("اصنع مقطعا", systemImage: "play.rectangle")
                        .font(.ui(.footnote, .semibold))
                        .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                        .overlay(Capsule().stroke(Brand.onDeepAccent.opacity(0.6), lineWidth: 1))
                }
                Spacer(minLength: 0)
                ShareLink(item: "﴿\(text)﴾ [\(AyahOfTheDay.reference(p))]") {
                    Image(systemName: "square.and.arrow.up").frame(width: Brand.minTap, height: Brand.minTap)
                }
                .accessibilityLabel("مشاركة")
                Button { favorites = Favorites.toggled(favorites, first) } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart").frame(width: Brand.minTap, height: Brand.minTap)
                }
                .accessibilityLabel(isFav ? "أزل من المفضلة" : "أضف للمفضلة")
            }
        }
        .padding(22)
        .emeraldPanel()
    }

    /// The site's tool groups (docs/site_snapshot: groups), each a card of quick links.
    private var toolGroups: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("أدوات تكمل يومك مع القرآن").font(.ui(.title3, .semibold))
                Text("كلها مجانية وتعمل على جهازك").font(.ui(.footnote)).foregroundStyle(Brand.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(HomeToolGroup.all) { g in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            StarOrnament().frame(width: 16, height: 16)
                            Text(g.title).font(.ui(.headline))
                        }
                        FlowLayout(spacing: 8) {
                            ForEach(g.links) { l in
                                NavigationLink { l.destination() } label: {
                                    Label(l.title, systemImage: l.symbol)
                                        .font(.ui(.footnote, .medium))
                                        .foregroundStyle(Brand.primaryInk)
                                        .padding(.horizontal, 12).frame(minHeight: 36)
                                        .background(Brand.tint, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .card()
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Image("LogoFull").resizable().scaledToFit().frame(width: 64, height: 64).opacity(0.9)
                .accessibilityHidden(true)
            Text("مجاني بالكامل · بلا حساب · بلا علامة مائية").font(.ui(.caption)).foregroundStyle(Brand.muted)
            Text("نسأل الله أن يجعله صدقة جارية").font(.ui(.caption, .medium)).foregroundStyle(Brand.goldInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var continueReading: some View {
        let page = max(lastPage, 1)
        let first = (try? lib.store?.page(page))?.first
        let name = first.flatMap { lib.surah($0.surah)?.shortName } ?? ""
        return NavigationLink { MushafReader(startPage: page) } label: {
            HStack(spacing: 14) {
                Image(systemName: "book").font(.ui(.title3)).foregroundStyle(Brand.primary)
                    .frame(width: 44, height: 44).background(Brand.tint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) {
                    Text(lastPage > 0 ? "تابع القراءة" : "ابدأ القراءة").font(.ui(.headline)).foregroundStyle(.primary)
                    Text("\(name) · صفحة \(Num.int(page))").font(.ui(.footnote)).foregroundStyle(Brand.muted)
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
                Text("آخر المشاريع").font(.ui(.headline))
                Spacer()
                if !recent.isEmpty {
                    NavigationLink("عرض الكل") { LibraryView(initial: .projects) }.font(.ui(.subheadline))
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
                            Image(systemName: "plus").font(.ui(.title3))
                            Text("مشروع جديد").font(.ui(.caption))
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
            case .downloads: DownloadsView()
            case .plans:
                List {
Group {
                    NavigationLink { KhatmaView() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("خطة الختمة").font(.ui(.headline))
                                Text(khatmaLine).font(.ui(.caption)).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "calendar").foregroundStyle(Brand.primary) }
                        .frame(minHeight: Brand.minTap)
                    }
                
}.listRowBackground(Brand.surface)
}
            }
        }
        .brandScreen()
        .navigationTitle("مكتبتي")
    }

    @AppStorage(KhatmaStore.key) private var khatmaRaw = ""

    private var khatmaLine: String {
        guard let p = KhatmaStore.load(khatmaRaw) else { return "وزع الختمة على الأيام والصلوات" }
        let d = min(max(p.day(on: Date()), 1), p.days)
        guard let r = p.range(day: d) else { return "اليوم \(Num.int(d)) من \(Num.int(p.days))" }
        return "اليوم \(Num.int(d)) من \(Num.int(p.days)) · ورد اليوم: صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound))"
    }

    private var favoritesList: some View { SavedAyatList() }
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
                if project.kind == .clip { Image(systemName: "play.fill").font(.ui(.caption2)) }
                Text(project.subtitle).font(.ui(.caption2, .medium))
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
                                Text(p.title).font(.ui(.caption)).lineLimit(1)
                                Text(p.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Num.locale)))
                                    .font(.ui(.caption2)).foregroundStyle(.secondary)
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
                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)
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
        .brandScreen()
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("حذف المشروع من مكتبتي؟", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("حذف", role: .destructive) { ProjectStore.shared.delete(project); dismiss() }
        }
        .alert("حفظ في الصور", isPresented: $saved) { Button("حسنا", role: .cancel) {} }
    }
}

// MARK: - Home tool groups and ornament

/// The site's eight-point star (--star): two gold squares and a dot.
struct StarOrnament: View {
    var color: Color = Brand.accent
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Rectangle().stroke(color, lineWidth: max(1, s / 17)).frame(width: s * 0.5, height: s * 0.5)
                Rectangle().stroke(color, lineWidth: max(1, s / 17)).frame(width: s * 0.5, height: s * 0.5).rotationEffect(.degrees(45))
                Circle().fill(color).frame(width: s * 0.18, height: s * 0.18)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct HomeToolLink: Identifiable {
    let title: String
    let symbol: String
    let destination: () -> AnyView
    var id: String { title }
}

struct HomeToolGroup: Identifiable {
    let title: String
    let links: [HomeToolLink]
    var id: String { title }

    private static func tool(_ t: ToolItem) -> HomeToolLink {
        HomeToolLink(title: t.title, symbol: t.symbol) { AnyView(t.destination) }
    }

    /// Same four groups and order as the site (/tools/).
    static let all: [HomeToolGroup] = [
        .init(title: "صناعة المحتوى", links: [
            .init(title: "مقطع قرآني", symbol: "play.rectangle") { AnyView(ClipMakerView()) },
            .init(title: "بطاقة آية", symbol: "rectangle.portrait") { AnyView(AyahCardView()) },
            .init(title: "بطاقة حديث", symbol: "text.book.closed") { AnyView(HadithView()) },
            .init(title: "المفضلة", symbol: "heart") { AnyView(LibraryView(initial: .favorites)) },
        ]),
        .init(title: "القرآن", links: [
            .init(title: "المصحف", symbol: "book") { AnyView(QuranView()) },
            .init(title: "التجويد", symbol: "paintpalette") { AnyView(TajweedView()) },
            .init(title: "معاني الكلمات", symbol: "character.book.closed") { AnyView(WordByWordView()) },
            .init(title: "آيات بالموضوع", symbol: "leaf") { AnyView(TopicsView()) },
            .init(title: "اختبار الحفظ", symbol: "eye.slash") { AnyView(HifzTestView()) },
            .init(title: "الختمة", symbol: "calendar") { AnyView(KhatmaView()) },
            .init(title: "الإذاعات", symbol: "antenna.radiowaves.left.and.right") { AnyView(RadioView()) },
            .init(title: "الرقية", symbol: "shield") { AnyView(RuqyaView()) },
            .init(title: "الأسماء الحسنى", symbol: "sparkles") { AnyView(AsmaView()) },
        ]),
        .init(title: "أدوات يومية", links: [ToolItem.azkar, .duas, .prayer, .qibla, .hijri, .occasions, .zakat, .tasbih, .qada, .sawm, .mosques].map(tool)),
        .init(title: "الحديث والتعلم", links: ToolItem.allCases.filter { [.hadith, .hadithChecker, .prayerGuide].contains($0) || $0.rawValue.hasPrefix("kids") }.map(tool)),
    ]
}
