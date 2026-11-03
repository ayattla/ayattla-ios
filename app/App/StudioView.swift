import SwiftUI
import AyatDesign

/// Studio tab: every creator from docs/APP_ARCHITECTURE.md. The video engine is not built yet,
/// so only the ayah card opens an editor; the rest stay listed and marked as coming.
struct StudioView: View {
    enum Creator: String, CaseIterable, Identifiable {
        case clip, card, status, dedication, hadithCard, asmaCard
        var id: String { rawValue }
        var title: String {
            switch self {
            case .clip: "مقطع قرآني"
            case .card: "بطاقة آية"
            case .status: "حالة"
            case .dedication: "إهداء"
            case .hadithCard: "بطاقة حديث"
            case .asmaCard: "بطاقة اسم"
            }
        }
        var subtitle: String {
            switch self {
            case .clip: "آيات بصوت القارئ وتظليل الكلمات"
            case .card: "صورة بالمقاس الذي تريد"
            case .status: "آية أو ذكر أو حديث"
            case .dedication: "صدقة جارية أو إهداء باسم"
            case .hadithCard: "حديث صحيح مع مصدره"
            case .asmaCard: "من الأسماء الحسنى"
            }
        }
        var symbol: String {
            switch self {
            case .clip: "play.rectangle"
            case .card: "rectangle.portrait"
            case .status: "text.bubble"
            case .dedication: "gift"
            case .hadithCard: "text.book.closed"
            case .asmaCard: "sparkles"
            }
        }
        var isReady: Bool { true }
    }

    @ViewBuilder private func destination(_ c: Creator) -> some View {
        switch c {
        case .card: AyahCardView()
        case .clip: ClipMakerView()
        case .status: StatusSourceView()
        case .dedication: AyahCardView(surah: 2, from: 201, templateID: "ihdaa")
        case .hadithCard: HadithView()
        case .asmaCard: AsmaView()
        }
    }

    /// Studio root (v2): hero, new-design cards, ready-made templates, then recent work.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                HeroHeader(eyebrow: "الاستوديو", title: "صناعة المحتوى",
                           subtitle: "مقاطع وبطاقات وحالات بهوية آيات تتلى، تصنع على جهازك بلا علامة مائية") {
                    HStack(spacing: Brand.Space.s) {
                        NavigationLink { ClipMakerView() } label: { Label("مقطع جديد", systemImage: "plus") }
                            .buttonStyle(.brandGold)
                        NavigationLink { LibraryView(initial: .projects) } label: { Label("مكتبتي", systemImage: "books.vertical") }
                            .buttonStyle(GhostOnEmerald())
                    }
                    .padding(.top, Brand.Space.xs)
                }

                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    SectionHeader("تصميم جديد")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: Brand.Space.s)], spacing: Brand.Space.s) {
                        ForEach(Creator.allCases) { c in
                            NavigationLink { destination(c) } label: {
                                ServiceCard(c.title, subtitle: c.subtitle, symbol: c.symbol, style: c == .clip ? .emerald : .gold)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }

                PresetStrip()

                RecentProjectsStrip()
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("صناعة المحتوى")
    }
}

/// Latest saved projects with a shortcut to the library (shared by home and studio).
struct RecentProjectsStrip: View {
    var body: some View {
        let recent = Array(ProjectStore.shared.projects.prefix(8))
        VStack(alignment: .leading, spacing: Brand.Space.m) {
            SectionHeader("آخر المشاريع", subtitle: recent.isEmpty ? "ما تحفظه يظهر هنا لتعيد فتحه وتعديله" : nil) {
                if !recent.isEmpty {
                    NavigationLink("عرض الكل") { LibraryView(initial: .projects) }.font(.ui(.subheadline, .medium))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Brand.Space.s) {
                    ForEach(recent) { p in
                        NavigationLink { ProjectDetailView(project: p) } label: { ProjectTile(project: p, width: 110) }
                            .buttonStyle(.pressable)
                    }
                    NavigationLink { ClipMakerView() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.ui(.title3))
                            Text("مشروع جديد").font(.ui(.caption))
                        }
                        .foregroundStyle(Brand.primaryInk)
                        .frame(width: 110, height: 150)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5])).foregroundStyle(Brand.lineStrong))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Brand.Space.l)
            }
            .padding(.horizontal, -Brand.Space.l)
        }
    }
}

/// Status (site's status editor): pick what it is made from, or start from a ready status design.
/// Every editor offers the three outputs: still image, video with recitation, animated text.
struct StatusSourceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                HeroHeader(eyebrow: "حالات واتساب", title: "صمم حالتك",
                           subtitle: "صورة ثابتة، أو فيديو بالتلاوة، أو نص متحرك بلا صوت، بمقاس الحالة ١٠٨٠×١٩٢٠")
                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    SectionHeader("من أين تبدأ؟")
                    NavigationLink {
                        AyahCardView(settings: .init(surah: 2, from: 255, to: 255, ratio: "9:16", background: "emerald",
                                                     fontScale: 1, template: "", name: ""))
                    } label: { ServiceCard("آية", subtitle: "بالرسم العثماني من المصحف الموثق", symbol: "book", style: .emerald) }
                    NavigationLink { AzkarView() } label: {
                        ServiceCard("ذكر", subtitle: "من حصن المسلم، ثم «اصنع حالة» تحت الذكر", symbol: "sun.max")
                    }
                    NavigationLink { HadithView() } label: {
                        ServiceCard("حديث صحيح أو حسن", subtitle: "بالراوي والمصدر والحكم من الدرر السنية", symbol: "text.book.closed")
                    }
                }
                .buttonStyle(.pressable)
                PresetStrip(title: "حالات جاهزة", subtitle: "اضغط على حالة لتعدلها وتشاركها", presets: StudioPreset.statuses)
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("حالة")
        .navigationBarTitleDisplayMode(.inline)
    }
}
