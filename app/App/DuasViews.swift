import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Duas (/tools/duas)

struct DuasView: View {
    private let data = ContentLibrary.shared.duas
    private let lib = ContentLibrary.shared
    @State private var section = 0

    var body: some View {
        Group {
            if let d = data {
                List {
Group {
                    Picker("القسم", selection: $section) {
                        Text("من القرآن").tag(0)
                        Text("حسب الحاجة").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    if section == 0 {
                        ForEach(d.quran, id: \.self) { q in quranDua(q) }
                    } else {
                        ForEach(d.needs, id: \.need) { n in
                            NavigationLink { NeedView(need: n) } label: { Text(n.need).frame(minHeight: Brand.minTap) }
                        }
                    }
                
}.listRowBackground(Brand.surface)
}
            } else {
                ContentUnavailableView("الأدعية غير متاحة", systemImage: "hands.sparkles",
                                       description: Text("لم تجهز حزمة المحتوى في هذه النسخة"))
            }
        }
        .brandScreen()
        .navigationTitle("الأدعية")
    }

    private func quranDua(_ q: DuasData.QuranRef) -> some View {
        let ayat = (try? lib.store?.ayat(surah: q.s, from: q.a, to: q.b)) ?? []
        let text = ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " ")
        let name = lib.surah(q.s)?.shortName ?? ""
        let ref = q.a == q.b ? "[\(name): \(Num.int(q.a))]" : "[\(name): \(Num.int(q.a))–\(Num.int(q.b))]"
        return VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.custom(ContentLibrary.mushafFont, size: 20, relativeTo: .body)).lineSpacing(8)
            HStack {
                Text(ref).font(.ui(.caption)).foregroundStyle(Brand.primaryInk)
                Spacer()
                NavigationLink { AyahCardView(surah: q.s, from: q.a, to: q.b) } label: { Image(systemName: "rectangle.portrait") }
                    .buttonStyle(.borderless).accessibilityLabel("اصنع بطاقة")
                ShareLink(item: "﴿\(text)﴾ \(ref)") { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless).accessibilityLabel("مشاركة")
            }
        }
        .padding(.vertical, 6)
    }
}

struct NeedView: View {
    let need: DuasData.Need
    var body: some View {
        List {
Group {
            ForEach(need.chapters, id: \.name) { c in
                Section(c.name) {
                    ForEach(c.items, id: \.self) { it in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(it.text).font(.custom("Amiri", size: 19, relativeTo: .body)).lineSpacing(6).textSelection(.enabled)
                            HStack {
                                Spacer()
                                NavigationLink { TextCardView(title: "حالة", text: it.text, reference: c.name, initialRatio: .story) } label: {
                                    Image(systemName: "rectangle.portrait")
                                }
                                .buttonStyle(.borderless).accessibilityLabel("اصنع حالة")
                                ShareLink(item: it.text) { Image(systemName: "square.and.arrow.up") }
                                    .buttonStyle(.borderless).accessibilityLabel("مشاركة")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle(need.need)
        .navigationBarTitleDisplayMode(.inline)
    }
}
