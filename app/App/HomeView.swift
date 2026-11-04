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

/// Home (v3): ayattla.com's home page made native — hero with the site's headline and badges, the
/// ayah of the day as the "phone" card, today's essentials as a bento row, then the site's sections
/// (products, how it works, features, tool directory, numbers, questions, closing call).
struct HomeView: View {
    @AppStorage("quran.lastPage") private var lastPage = 0
    @AppStorage(Favorites.key) private var favorites = ""
    @Environment(\.dynamicTypeSize) private var typeSize
    private let lib = ContentLibrary.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.xxl) {
                hero
                if lib.isReady { ayahCard }
                today
                HomeProducts()
                PresetStrip()
                HomeSources()
                RecentProjectsStrip()
                HomeSteps()
                HomeFeatures()
                toolDirectory
                HomeStats()
                HomeFAQ()
                HomeClosing()
                footer
            }
            .padding(.horizontal, Brand.Space.l).padding(.vertical, Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack(alignment: .top) {
                Brand.page
                // The site hero's glow: green top-right, teal under the headline.
                RadialGradient(colors: [Brand.green.opacity(0.18), .clear], center: UnitPoint(x: 0.1, y: 0), startRadius: 0, endRadius: 380)
                    .frame(height: 520)
                RadialGradient(colors: [Brand.teal.opacity(0.10), .clear], center: UnitPoint(x: 0.95, y: 0.6), startRadius: 0, endRadius: 320)
                    .frame(height: 620)
            }
            .ignoresSafeArea()
        }
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

    /// The site's hero: badge pill, two-line headline (second line in the green gradient), lead,
    /// primary and secondary actions, then the four sizes.
    private var hero: some View {
        VStack(spacing: Brand.Space.l) {
            FlowLayout(spacing: 14) {
                ForEach(["مجاني بالكامل", "بدون تسجيل", "بدون علامة مائية"], id: \.self) { t in
                    HStack(spacing: 6) {
                        Circle().fill(Brand.green).frame(width: 7, height: 7)
                        Text(t).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.ink)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Brand.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Brand.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x0F1F17).opacity(0.08), radius: 12, y: 6)

            VStack(spacing: 2) {
                Text("آيات تتلى كلمة كلمة").foregroundStyle(Brand.ink)
                Text("في مقطع جاهز للنشر").foregroundStyle(Brand.siteGradient)
            }
            .font(.ui(.largeTitle, .bold))
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Text("اختر الآيات والقارئ، فيظهر النص بخط المصحف ويتلون مع التلاوة لحظة بلحظة. أربعة مقاسات للريلز والستوري ويوتيوب، وقوالب للإهداء والصدقة الجارية.")
                .font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                NavigationLink { ClipMakerView() } label: {
                    Label("ابدأ مجانا الآن", systemImage: "play.rectangle").frame(maxWidth: 320)
                }
                .buttonStyle(.brandPrimary)
                NavigationLink { StatusSourceView() } label: {
                    Label("صمم حالة واتساب", systemImage: "photo").frame(maxWidth: 320)
                }
                .buttonStyle(.brandSecondary)
            }
            .padding(.top, 4)
            Text(Num.hijri(Date())).font(.ui(.caption, .medium)).foregroundStyle(Brand.muted)
        }
        .padding(.top, Brand.Space.s)
    }

    /// Ayah of the day drawn like the site's phone preview: emerald screen with the gold frame,
    /// floating chips, and actions.
    private var ayahCard: some View {
        let p = AyahOfTheDay.pick()
        let ayat = (try? lib.store?.ayat(surah: p.surah, from: p.from, to: p.to)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let first = RecitationPlayer.Position(surah: p.surah, ayah: p.from)
        let isFav = Favorites.list(favorites).contains(first)
        return VStack(spacing: 14) {
            HStack {
                Eyebrow("آية اليوم")
                    .environment(\.colorScheme, .dark)
                Spacer()
                Text(AyahOfTheDay.reference(p)).font(.ui(.footnote, .semibold)).foregroundStyle(Brand.onDeepAccent)
            }
            Text(text)
                .font(.custom(ContentLibrary.mushafFont, size: 24, relativeTo: .title3))
                .lineSpacing(12)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(7)
                .padding(.vertical, 6)
            HStack(spacing: 8) {
                NavigationLink { MushafReader(startPage: ayat.first?.page ?? 1, focus: first) } label: {
                    Label("اقرأ في المصحف", systemImage: "book").font(.ui(.footnote, .semibold))
                        .foregroundStyle(Brand.primary)
                        .padding(.horizontal, 14).frame(minHeight: Brand.minTap)
                        .background(Brand.onDeepAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                NavigationLink { ClipMakerView(surah: p.surah, from: p.from, to: p.to) } label: {
                    Label("اصنع مقطعا", systemImage: "play.rectangle").font(.ui(.footnote, .semibold))
                        .padding(.horizontal, 12).frame(minHeight: Brand.minTap)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.onDeepAccent.opacity(0.45), lineWidth: 1))
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
        .heroSurface(radius: 30)
        // Floating chips, as on the site's phone preview.
        .overlay(alignment: .topLeading) {
            chip("تظليل الكلمة مع التلاوة", symbol: "checkmark.circle.fill").offset(x: 10, y: -16)
        }
        .overlay(alignment: .bottomTrailing) {
            chip("+٣٠ قارئا", symbol: "waveform").offset(x: -10, y: 16)
        }
        .padding(.vertical, 12)
    }

    private func chip(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.ui(.caption, .semibold)).foregroundStyle(Brand.ink)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Brand.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Brand.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x0F1F17).opacity(0.18), radius: 10, y: 6)
            .accessibilityHidden(true)
    }

    /// Today's essentials as a bento: next prayer (wide), then reading and azkar side by side.
    private var today: some View {
        VStack(spacing: Brand.Space.m) {
            NextPrayerCard()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.Space.m),
                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: Brand.Space.m) {
                if lib.isReady { continueReading }
                NavigationLink { AzkarView() } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        IconTile("sun.horizon", style: .gradient(2), size: 44)
                        Text("أذكار اليوم").font(.ui(.headline)).foregroundStyle(Brand.ink)
                        Text("الصباح والمساء والنوم مع العداد").font(.ui(.caption)).foregroundStyle(Brand.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .surface(.raised)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    /// The site's tool directory: four groups, each with its title between two green rules and a
    /// grid of compact tool tiles, then «كل الأدوات».
    private var toolDirectory: some View {
        VStack(spacing: Brand.Space.xl) {
            SiteSectionHead(eyebrow: "الأدوات", "أدوات تكمل يومك مع القرآن", subtitle: "كلها مجانية وتعمل على جهازك")
            ForEach(SiteTool.Group.allCases) { g in
                VStack(spacing: Brand.Space.m) {
                    HStack(spacing: 10) {
                        LinearGradient(colors: [.clear, Brand.green.opacity(0.45)], startPoint: .leading, endPoint: .trailing).frame(height: 2)
                        Text(g.title).font(.ui(.headline)).foregroundStyle(Brand.ink).fixedSize()
                        LinearGradient(colors: [Brand.green.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing).frame(height: 2)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                             count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 10) {
                        ForEach(SiteTool.all.filter { $0.group == g }) { t in
                            NavigationLink { t.destination } label: { SiteToolCard(tool: t, compact: true) }
                                .buttonStyle(.pressable)
                        }
                    }
                }
            }
            NavigationLink { ToolsView() } label: { Label("كل الأدوات", systemImage: "square.grid.2x2").frame(maxWidth: 320) }
                .buttonStyle(.brandSecondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Image("LogoFull").resizable().scaledToFit().frame(width: 72, height: 72)
                .padding(10).background(Brand.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color(hex: 0x0F1F17).opacity(0.08), radius: 12, y: 6)
                .accessibilityHidden(true)
            Text("صانع مقاطع وبطاقات قرآنية مجاني، صدقة جارية لكل من شارك").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
            Text("© آيات تتلى — ayattla.com").font(.ui(.caption2)).foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.Space.l)
    }

    private var continueReading: some View {
        let page = max(lastPage, 1)
        let first = (try? lib.store?.page(page))?.first
        let name = first.flatMap { lib.surah($0.surah)?.shortName } ?? ""
        return NavigationLink { MushafReader(startPage: page) } label: {
            VStack(alignment: .leading, spacing: 10) {
                IconTile("book.pages", style: .gradient(0), size: 44)
                Text(lastPage > 0 ? "تابع القراءة" : "ابدأ القراءة").font(.ui(.headline)).foregroundStyle(Brand.ink)
                Text("\(name) · صفحة \(Num.int(page))").font(.ui(.caption)).foregroundStyle(Brand.muted)
                ProgressView(value: Double(page), total: Double(max(lib.pageCount, 1))).tint(Brand.green)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .surface(.raised)
        }
        .buttonStyle(.pressable)
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
            summary
                .padding(.horizontal, Brand.Space.l).padding(.top, Brand.Space.s)
            Picker("أقسام المكتبة", selection: $section) {
                ForEach(Section.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Brand.Space.l).padding(.vertical, Brand.Space.s)
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

    /// Counts of what the library holds; tapping one opens its section.
    private var summary: some View {
        HStack(spacing: Brand.Space.s) {
            stat(ProjectStore.shared.projects.count, "مشروع", "square.stack", .projects)
            stat(Favorites.list(favorites).count, "محفوظة", "heart", .favorites)
            stat(KhatmaStore.load(khatmaRaw) == nil ? 0 : 1, "خطة", "calendar", .plans)
        }
    }

    private func stat(_ n: Int, _ label: String, _ symbol: String, _ s: Section) -> some View {
        Button { withAnimation(.snappy) { section = s } } label: {
            HStack(spacing: Brand.Space.s) {
                IconTile(symbol, style: section == s ? .emerald : .gold, size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Num.int(n)).font(.ui(.headline)).foregroundStyle(Brand.ink)
                    Text(label).font(.ui(.caption2)).foregroundStyle(Brand.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(Brand.Space.s + 2)
            .surface(section == s ? .gold : .raised, radius: 16)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(Num.int(n)) \(label)")
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
