import SwiftUI
import AyatDesign

/// «الأذكار والحديث» section of the bottom bar: the site's azkar, duas and hadith tools in one
/// place, grouped as on the site's tool directory (أدوات يومية، الحديث والتعلم). Each card opens
/// the same native screen as everywhere else in the app.
struct AzkarHadithView: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                HeroHeader(eyebrow: "حصن المسلم والسنة", title: "الأذكار والحديث",
                           subtitle: "أذكارك اليومية بعداد يحفظ تقدمك، وأدعية من القرآن والسنة، وأحاديث صحيحة وحسنة بمصادرها")
                dailyAzkar
                group("الأذكار والأدعية", subtitle: "من حصن المسلم ومن القرآن والسنة، مع المصدر") {
                    link("الأذكار", "أذكار الصباح والمساء والنوم مع العداد", "sun.max") { AzkarView() }
                    link("أدعية من القرآن والسنة", "مصنفة حسب الحاجة مع المصدر", "hands.sparkles") { DuasView() }
                    link("الرقية الشرعية", "آيات الرقية من القرآن تتلى متتابعة", "play.circle") { RuqyaView() }
                    link("المسبحة الإلكترونية", "عداد تسبيح يحفظ العدد على جهازك", "circle.circle") { TasbihView() }
                    link("أسماء الله الحسنى", "بطاقة لكل اسم من الأسماء الحسنى", "sparkles") { AsmaView() }
                }
                group("الحديث والتعلم", subtitle: "أحاديث صحيحة وحسنة فقط، بالراوي والمصدر والحكم من الدرر السنية") {
                    link("الأحاديث النبوية حسب الموضوع", "أحاديث صحيحة وحسنة بالتخريج والحكم والشرح", "text.book.closed") { HadithView() }
                    link("التحقق من حديث", "الصق حديثا وصلك لتعرف تخريجه وحكمه", "checkmark.seal") { HadithCheckerView() }
                    link("بطاقات الأحاديث الصحيحة", "حديث صحيح أو حسن مع الراوي والمصدر والحكم", "rectangle.portrait") { HadithView() }
                    link("صفة الوضوء والصلاة", "من الأحاديث الصحيحة مع الشرح", "drop") { PrayerGuideView() }
                    link("تحفيظ الأطفال جزء عم", "استماع وتكرار ونجوم وشهادة باسم الطفل", "star.circle") { KidsJuzAmmaView() }
                }
            }
            .padding(Brand.Space.l)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("الأذكار والحديث")
    }

    /// Shortcut row to the four daily chapters, opened straight into the counter.
    private var dailyAzkar: some View {
        let cats = (try? ContentLibrary.shared.store?.azkarCategories()) ?? []
        let pinned = AzkarView.pinned.prefix(4).compactMap { t in cats.first { $0.title == t } }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("أذكار اليوم", subtitle: "يحفظ العداد تقدمك اليوم على جهازك")
            if pinned.isEmpty {
                Text("الأذكار غير متاحة في هذه النسخة").font(.ui(.footnote)).foregroundStyle(Brand.muted)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                    ForEach(pinned) { c in
                        NavigationLink { AzkarSession(category: c) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: AzkarView.symbol(c.title)).font(.ui(.title3))
                                    .foregroundStyle(Brand.onDeepAccent)
                                Text(c.title).font(.ui(.subheadline, .semibold)).multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .emeraldPanel(radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, subtitle: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title, subtitle: subtitle)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 600 : 300), spacing: 10)], spacing: 10) {
                content()
            }
        }
    }

    private func link<D: View>(_ title: String, _ subtitle: String, _ symbol: String, @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: { ToolCard(title, subtitle: subtitle, symbol: symbol) }
            .buttonStyle(.plain)
    }
}
