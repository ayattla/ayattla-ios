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
        var isReady: Bool { self == .card }
    }

    var body: some View {
        List {
            Section("مشروع جديد") {
                ForEach(Creator.allCases) { c in
                    NavigationLink {
                        if c.isReady { AyahCardView() } else { PlaceholderScreen(title: c.title) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: c.symbol).font(.title3).foregroundStyle(Brand.primary)
                                .frame(width: 44, height: 44).background(Brand.tint, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title).font(.headline)
                                Text(c.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !c.isReady { Text("قريبا").font(.caption).foregroundStyle(.secondary) }
                        }
                        .frame(minHeight: Brand.minTap)
                    }
                }
            }
        }
        .navigationTitle("الاستوديو")
    }
}
