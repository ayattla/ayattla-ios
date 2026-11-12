import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Hadith row (shared by browse, checker and guide)

struct HadithRow: View {
    let text: String
    let source: String
    let grade: String
    let category: String?
    let url: String
    var match: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let match {
                    Text("التطابق \(Num.int(match))٪").font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Brand.tint, in: Capsule())
                }
                if !grade.isEmpty {
                    Text(grade).font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Brand.goldSoft, in: Capsule())
                        .accessibilityLabel("الحكم: \(grade)")
                }
                if let category, !category.isEmpty {
                    Text(category).font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(1)
                }
            }
            Text(text).font(.custom("Amiri", size: 18, relativeTo: .body)).lineSpacing(6).textSelection(.enabled)
                .foregroundStyle(Brand.ink)
            if !source.isEmpty {
                Text(source).font(.ui(.caption)).foregroundStyle(Brand.muted)
            }
            // Labeled actions (the icon-only row was flagged in the quality review).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actions }
                VStack(alignment: .leading, spacing: 8) { actions }
            }
            .font(.ui(.caption, .semibold))
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder private var actions: some View {
        if let u = URL(string: url), !url.isEmpty {
            Link(destination: u) { action("الشرح", "arrow.up.left.square") }
        }
        NavigationLink { TextCardView(title: "بطاقة حديث", text: text, reference: [source, grade].filter { !$0.isEmpty }.joined(separator: " · ")) } label: {
            action("اصنع بطاقة", "rectangle.portrait")
        }
        ShareLink(item: "\(text)\n\n\(source)") { action("مشاركة", "square.and.arrow.up") }
    }

    private func action(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .foregroundStyle(Brand.primaryInk)
            .padding(.horizontal, 12).frame(minHeight: Brand.minTap)
            .background(Brand.tint, in: Capsule())
    }
}

// MARK: - Hadith (/tools/hadith)

struct HadithView: View {
    @State private var cats: [SiteAPI.HadithPage.Cat] = []
    @State private var cat = ""
    @State private var query = ""
    @State private var items: [SiteAPI.Hadith] = []
    @State private var page = 1
    @State private var total = 0
    @State private var loading = false
    @State private var failed = false
    /// Only the latest request may write results (a quick category switch used to let an older
    /// response overwrite a newer one).
    @State private var request = 0

    var body: some View {
        List {
            ToolHeadSection(id: "hadith")
Group {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("الكل", "")
                        ForEach(cats, id: \.name) { c in chip("\(c.name) (\(Num.int(c.count)))", c.name) }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            Section {
                ForEach(items) { h in
                    HadithRow(text: h.text, source: h.source, grade: h.grade, category: h.cat, url: h.url)
                }
                if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                if !loading && items.count < total {
                    Button("عرض المزيد") { Task { await load(more: true) } }.frame(maxWidth: .infinity)
                }
            } header: {
                if total > 0 { Text("\(Num.int(total)) حديثا") }
            } footer: {
                Text("من موسوعة الأحاديث النبوية (hadeethenc.com)، بالتخريج والحكم ورابط الشرح.")
            }
        
}.listRowBackground(Brand.surface)
}
        .overlay {
            if failed && items.isEmpty {
                ContentUnavailableView {
                    Label("تعذر التحميل الآن", systemImage: "wifi.exclamationmark")
                } description: { Text("تحقق من الاتصال ثم حاول مرة أخرى") } actions: {
                    Button("إعادة المحاولة") { Task { await load(more: false) } }
                }
            } else if !loading && items.isEmpty && total == 0 && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .brandScreen()
        .navigationTitle("الأحاديث")
        .searchable(text: $query, prompt: "ابحث في الأحاديث")
        .onSubmit(of: .search) { Task { await load(more: false) } }
        .onChange(of: query) { _, q in if q.isEmpty { Task { await load(more: false) } } }
        .task { if items.isEmpty { await load(more: false) } }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        let on = cat == value
        return Button {
            cat = value
            Task { await load(more: false) }
        } label: {
            Text(title).font(.ui(.footnote, on ? .semibold : .medium)).foregroundStyle(on ? .white : Brand.ink)
                .padding(.horizontal, 14).frame(minHeight: 38)
                .background { if on { Capsule().fill(Brand.siteGradient) } else { Capsule().fill(Color.cardSurface) } }
                .overlay(Capsule().stroke(on ? .clear : Brand.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func load(more: Bool) async {
        request += 1
        let mine = request
        loading = true; failed = false
        let p = more ? page + 1 : 1
        do {
            let r = try await SiteAPI.hadith(cat: cat, page: p, query: query.trimmingCharacters(in: .whitespaces))
            guard mine == request else { return }
            if cats.isEmpty { cats = r.cats }
            items = more ? items + r.items : r.items
            total = r.total; page = p
        } catch {
            guard mine == request else { return }
            failed = true
        }
        loading = false
    }
}

// MARK: - Hadith checker (/tools/hadith-checker)

struct HadithCheckerView: View {
    @State private var text = ""
    @State private var result: SiteAPI.HadithCheck?
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        Form {
            ToolHeadSection(id: "hadith-checker")
Group {
            Section {
                TextField("الصق نص الحديث أو جزءا منه", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                Button {
                    Task { await check() }
                } label: {
                    if loading { ProgressView() } else { Text("تحقق").font(.ui(.headline)) }
                }
                .frame(maxWidth: .infinity, minHeight: Brand.minTap)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 || loading)
            } footer: {
                Text("يبحث في موسوعة الأحاديث النبوية ويعرض أقرب الأحاديث مع تخريجها وحكمها. النتيجة بحث وليست حكما من التطبيق؛ راجع أهل العلم.")
            }
            if failed {
                Section { Text("تعذر التحقق الآن، تحقق من الاتصال").foregroundStyle(.secondary) }
            }
            if let r = result {
                Section(r.items.isEmpty ? "لم يعثر على حديث مطابق في الموسوعة" : "أقرب النتائج") {
                    ForEach(r.items) { h in
                        HadithRow(text: h.text, source: h.source, grade: h.grade, category: h.cat, url: h.url, match: h.match)
                    }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("التحقق من حديث")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func check() async {
        loading = true; failed = false
        do { result = try await SiteAPI.checkHadith(text) } catch { failed = true }
        loading = false
    }
}

// MARK: - Prayer guide (/tools/prayer-guide)

struct PrayerGuideView: View {
    private let guide = ContentLibrary.shared.prayerGuide

    var body: some View {
        Group {
            if let g = guide {
                List {
                    ToolHeadSection(id: "prayer-guide")
Group {
                    Section { Text(g.lead).font(.ui(.subheadline)).foregroundStyle(.secondary) }
                    ForEach(g.sections, id: \.title) { s in
                        Section(s.title) {
                            ForEach(s.items, id: \.self) { h in
                                HadithRow(text: h.text, source: h.source, grade: h.grade, category: nil, url: h.url)
                            }
                        }
                    }
                
}.listRowBackground(Brand.surface)
}
            } else {
                ContentUnavailableView("غير متاح", systemImage: "drop", description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            }
        }
        .brandScreen()
        .navigationTitle("صفة الوضوء والصلاة")
        .navigationBarTitleDisplayMode(.inline)
    }
}
