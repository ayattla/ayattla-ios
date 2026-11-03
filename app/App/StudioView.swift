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

    var body: some View {
        List {
Group {
            Section {
                NavigationLink { LibraryView(initial: .projects) } label: {
                    Label { Text("مكتبتي: المشاريع والمفضلة والتنزيلات").font(.ui(.subheadline, .medium)) }
                        icon: { Image(systemName: "books.vertical").foregroundStyle(Brand.goldInk) }
                        .frame(minHeight: Brand.minTap)
                }
            }
            Section("مشروع جديد") {
                ForEach(Creator.allCases) { c in
                    NavigationLink {
                        switch c {
                        case .card: AyahCardView()
                        case .clip: ClipMakerView()
                        case .status: StatusSourceView()
                        case .dedication: AyahCardView(surah: 2, from: 201, templateID: "ihdaa")
                        case .hadithCard: HadithView()
                        case .asmaCard: AsmaView()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: c.symbol).font(.ui(.title3)).foregroundStyle(Brand.primary)
                                .frame(width: 44, height: 44).background(Brand.tint, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title).font(.ui(.headline))
                                Text(c.subtitle).font(.ui(.caption)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !c.isReady { Text("قريبا").font(.ui(.caption)).foregroundStyle(.secondary) }
                        }
                        .frame(minHeight: Brand.minTap)
                    }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("صناعة المحتوى")
    }
}

/// Status: choose what it is made from (ayah, dhikr or hadith), as in the site's status editor.
struct StatusSourceView: View {
    var body: some View {
        List {
Group {
            NavigationLink { AyahCardView(surah: 2, from: 255) } label: { Label("آية", systemImage: "book") }
            NavigationLink { AzkarView() } label: { Label("ذكر", systemImage: "sun.max") }
            NavigationLink { HadithView() } label: { Label("حديث صحيح", systemImage: "text.book.closed") }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("حالة")
        .navigationBarTitleDisplayMode(.inline)
    }
}
