import SwiftUI
import UIKit
import AyatDesign
import AyatContent

/// Counts done today per zikr id; starts fresh each day (design/Flows.dc.html: "العداد يحفظ التقدم اليومي").
enum AzkarProgress {
    private static let dayKey = "azkar.day"
    private static let countsKey = "azkar.counts"

    static func today(_ now: Date = Date()) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: now)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    static func counts(_ d: UserDefaults = .standard, now: Date = Date()) -> [String: Int] {
        guard d.string(forKey: dayKey) == today(now) else { return [:] }
        return d.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }

    static func set(_ id: Int, _ done: Int, _ d: UserDefaults = .standard, now: Date = Date()) {
        var c = counts(d, now: now)
        c[String(id)] = done
        d.set(today(now), forKey: dayKey)
        d.set(c, forKey: countsKey)
    }
}

/// Azkar from the content pack (chapters of Hisn al-Muslim), per design/Azkar.dc.html.
struct AzkarView: View {
    @State private var query = ""
    private let categories: [ZikrCategory] = (try? ContentLibrary.shared.store?.azkarCategories()) ?? []

    /// Chapters shown first, matched by their exact titles in the source.
    static let pinned = ["أذكار الصباح", "أذكار المساء", "أذكار النوم", "أذكار الاستيقاظ من النوم", "الأذكار بعد السلام من الصلاة"]

    var body: some View {
        Group {
            if categories.isEmpty {
                ContentUnavailableView("الأذكار غير متاحة", systemImage: "sun.max",
                                       description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            } else {
                List {
Group {
                    if query.isEmpty {
                        Section("اليومية") {
                            ForEach(pinnedCategories) { c in link(c, symbol: Self.symbol(c.title)) }
                        }
                    }
                    Section(query.isEmpty ? "كل الأبواب (\(Num.int(categories.count)))" : "النتائج") {
                        ForEach(filtered) { c in link(c, symbol: nil) }
                    }
                
}.listRowBackground(Brand.surface)
}
                .overlay { if !query.isEmpty && filtered.isEmpty { ContentUnavailableView.search(text: query) } }
            }
        }
        .brandScreen()
        .navigationTitle("الأذكار")
        .searchable(text: $query, prompt: "ابحث في الأبواب")
    }

    private var pinnedCategories: [ZikrCategory] {
        Self.pinned.compactMap { t in categories.first { $0.title == t } }
    }

    private var filtered: [ZikrCategory] {
        let q = ContentStore.clean(query.trimmingCharacters(in: .whitespaces))
        return q.isEmpty ? categories : categories.filter { ContentStore.clean($0.title).localizedStandardContains(q) }
    }

    private func link(_ c: ZikrCategory, symbol: String?) -> some View {
        NavigationLink { AzkarSession(category: c) } label: {
            if let symbol {
                Label { Text(c.title) } icon: { Image(systemName: symbol).foregroundStyle(Brand.primary) }
                    .frame(minHeight: Brand.minTap)
            } else {
                Text(c.title).frame(minHeight: Brand.minTap)
            }
        }
    }

    static func symbol(_ title: String) -> String {
        if title.contains("الصباح") { return "sunrise" }
        if title.contains("المساء") { return "sunset" }
        if title.contains("النوم") && !title.contains("الاستيقاظ") { return "moon.zzz" }
        if title.contains("الاستيقاظ") { return "sun.max" }
        return "hands.sparkles"
    }
}

/// One chapter, one zikr per page, with the counter.
struct AzkarSession: View {
    let category: ZikrCategory
    @State private var items: [Zikr] = []
    @State private var index = 0
    @State private var done: [Int: Int] = [:]
    @AppStorage("azkar.fontScale") private var fontScale = 1.0
    @AppStorage("tasbih.haptics") private var haptics = true

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: Double(completed), total: Double(max(items.count, 1)))
                .tint(Brand.primary)
                .padding(.horizontal, 16)
                .accessibilityLabel("أنجزت \(Num.int(completed)) من \(Num.int(items.count))")
            if items.isEmpty {
                Spacer()
            } else {
                TabView(selection: $index) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, z in
                        ZikrCard(zikr: z, scale: fontScale).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                counter
                actions
            }
        }
        .padding(.bottom, 12)
        .background(Brand.background)
        .brandScreen()
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(Num.int(min(index + 1, items.count))) / \(Num.int(items.count))")
                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { fontScale = min(fontScale + 0.15, 1.6) } label: { Label("تكبير الخط", systemImage: "textformat.size.larger") }
                    Button { fontScale = max(fontScale - 0.15, 0.8) } label: { Label("تصغير الخط", systemImage: "textformat.size.smaller") }
                    Button(role: .destructive) { resetAll() } label: { Label("إعادة العد", systemImage: "arrow.counterclockwise") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("خيارات")
            }
        }
        .onAppear(perform: load)
    }

    private var current: Zikr? { items.indices.contains(index) ? items[index] : nil }
    private var completed: Int { items.filter { (done[$0.id] ?? 0) >= $0.count }.count }
    private var remaining: Int { current.map { max($0.count - (done[$0.id] ?? 0), 0) } ?? 0 }

    private var counter: some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                if remaining == 0 {
                    Image(systemName: "checkmark").font(.ui(size: 44, .semibold))
                    Text("تم").font(.ui(.footnote)).opacity(0.9)
                } else {
                    Text(Num.int(remaining)).font(.ui(size: 52, .semibold)).monospacedDigit()
                    Text("متبق — اضغط للعد").font(.ui(.footnote)).opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(Brand.gradient,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel(remaining == 0 ? "اكتمل" : "عد مرة، متبق \(Num.int(remaining))")
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if let z = current {
                NavigationLink {
                    TextCardView(title: "حالة", text: z.text, reference: z.reference ?? category.title, initialRatio: .story)
                } label: { Text("اصنع حالة").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
                ShareLink(item: Self.shareText(z)) { Text("مشاركة").frame(maxWidth: .infinity, minHeight: Brand.minTap) }
            }
            Button { withAnimation { index = min(index + 1, items.count - 1) } } label: {
                Text("التالي").frame(maxWidth: .infinity, minHeight: Brand.minTap)
            }
            .disabled(index >= items.count - 1)
        }
        .font(.ui(.subheadline, .medium))
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.primary)
        .padding(.horizontal, 16)
    }

    static func shareText(_ z: Zikr) -> String {
        [z.text, z.reference].compactMap { $0 }.joined(separator: "\n\n")
    }

    private func load() {
        items = (try? ContentLibrary.shared.store?.azkar(category: category.id)) ?? []
        let saved = AzkarProgress.counts()
        done = Dictionary(uniqueKeysWithValues: items.map { ($0.id, saved[String($0.id)] ?? 0) })
        index = items.firstIndex { (done[$0.id] ?? 0) < $0.count } ?? 0
    }

    private func tap() {
        guard let z = current, remaining > 0 else {
            if index < items.count - 1 { withAnimation { index += 1 } }
            return
        }
        let n = (done[z.id] ?? 0) + 1
        done[z.id] = n
        AzkarProgress.set(z.id, n)
        if haptics { UIImpactFeedbackGenerator(style: n >= z.count ? .medium : .light).impactOccurred() }
        if n >= z.count, index < items.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation { index += 1 } }
        }
    }

    private func resetAll() {
        for z in items { done[z.id] = 0; AzkarProgress.set(z.id, 0) }
        index = 0
    }
}

struct ZikrCard: View {
    let zikr: Zikr
    let scale: Double

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Text exactly as the source has it, with its tashkeel.
                Text(zikr.text)
                    .font(.custom("Amiri", size: 21 * scale, relativeTo: .title3))
                    .lineSpacing(9)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .textSelection(.enabled)
                let meta = [zikr.reference, zikr.note].compactMap { $0?.isEmpty == false ? $0 : nil }
                if !meta.isEmpty {
                    Divider().overlay(Brand.line)
                    Text(meta.joined(separator: " · "))
                        .font(.ui(.caption)).foregroundStyle(Brand.muted)
                        .multilineTextAlignment(.center)
                }
                if zikr.count > 1 {
                    Text("العدد: \(Num.int(zikr.count))").font(.ui(.caption, .medium)).foregroundStyle(Brand.primaryInk)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 22)
            .card()
            .padding(.horizontal, 16)
        }
    }
}
