import SwiftUI
import AyatDesign

/// «الأذكار والحديث» section of the bottom bar: the site's azkar, duas and hadith tools in one
/// place, grouped as on the site's tool directory (أدوات يومية، الحديث والتعلم). Each row opens
/// the same native screen as everywhere else in the app. v3: page-head band, daily tiles, and
/// grouped rows with gradient icon tiles (as on the home and tools pages).
struct AzkarHadithView: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                head
                dailyAzkar
                group("الأذكار والأدعية", subtitle: "من حصن المسلم ومن القرآن والسنة، مع المصدر") {
                    row("حصن المسلم", "أبواب الأذكار والأدعية كاملة مع العداد", "shield.lefthalf.filled", 0) {
                        AzkarView(title: "حصن المسلم", showsDaily: false)
                    }
                    divider
                    row("الأذكار", "أذكار الصباح والمساء والنوم مع العداد", "sun.max", 1) { AzkarView() }
                    divider
                    row("أدعية من القرآن والسنة", "مصنفة حسب الحاجة مع المصدر", "hands.sparkles", 2) { DuasView() }
                    divider
                    row("الرقية الشرعية", "آيات الرقية من القرآن تتلى متتابعة", "play.circle", 3) { RuqyaView() }
                    divider
                    row("المسبحة الإلكترونية", "عداد تسبيح يحفظ العدد على جهازك", "circle.circle", 4) { TasbihView() }
                    divider
                    row("أسماء الله الحسنى", "بطاقة لكل اسم من الأسماء الحسنى", "sparkles", 0) { AsmaView() }
                }
                group("الحديث والتعلم", subtitle: "أحاديث صحيحة وحسنة فقط، بالراوي والمصدر والحكم من الدرر السنية") {
                    row("الأحاديث النبوية حسب الموضوع", "أحاديث صحيحة وحسنة بالتخريج والحكم والشرح", "text.book.closed", 1) { HadithView() }
                    divider
                    row("التحقق من حديث", "الصق حديثا وصلك لتعرف تخريجه وحكمه", "checkmark.seal", 2) { HadithCheckerView() }
                    divider
                    row("بطاقات الأحاديث الصحيحة", "حديث صحيح أو حسن مع الراوي والمصدر والحكم", "rectangle.portrait", 3) { HadithView() }
                    divider
                    row("صفة الوضوء والصلاة", "من الأحاديث الصحيحة مع الشرح", "drop", 4) { PrayerGuideView() }
                    divider
                    row("تحفيظ الأطفال جزء عم", "استماع وتكرار ونجوم وشهادة باسم الطفل", "star.circle", 0) { KidsJuzAmmaView() }
                }
            }
            .padding(.horizontal, Brand.Space.l).padding(.top, Brand.Space.s).padding(.bottom, Brand.Space.xl)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brandScreen()
        .navigationTitle("الأذكار والحديث")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Title and promise in the site's soft page-head band.
    private var head: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("حصن المسلم والسنة").font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Brand.tint, in: Capsule())
            Text("الأذكار والحديث").font(.ui(.title2, .bold)).foregroundStyle(Brand.ink)
                .accessibilityAddTraits(.isHeader)
            Text("أذكارك اليومية بعداد يحفظ تقدمك، وأدعية من القرآن والسنة، وأحاديث صحيحة وحسنة بمصادرها")
                .font(.ui(.footnote)).foregroundStyle(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Brand.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageHeadSurface()
    }

    /// Shortcut tiles to the four daily chapters, opened straight into the counter.
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
                    ForEach(Array(pinned.enumerated()), id: \.element.id) { i, c in
                        NavigationLink { AzkarSession(category: c) } label: {
                            HStack(spacing: 12) {
                                IconTile(AzkarView.symbol(c.title), style: .gradient(i + 1), size: 42)
                                Text(c.title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                            .surface(.raised, radius: 18)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    private var divider: some View { Divider().padding(.leading, 70) }

    private func group<Content: View>(_ title: String, subtitle: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title, subtitle: subtitle)
            VStack(spacing: 0) { content() }
                .surface(.raised)
        }
    }

    private func row<D: View>(_ title: String, _ subtitle: String, _ symbol: String, _ tile: Int,
                              @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: Brand.Space.m) {
                IconTile(symbol, style: .gradient(tile), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(.body, .semibold)).foregroundStyle(Brand.ink)
                    Text(subtitle).font(.ui(.footnote)).foregroundStyle(Brand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward").font(.ui(.footnote, .semibold)).foregroundStyle(Brand.lineStrong)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Brand.Space.l).padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}
