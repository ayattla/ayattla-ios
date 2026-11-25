import SwiftUI
import AyatDesign

// MARK: - Short religious bio phrases (/tools/bio)
// Data: App/bio_data.json, same file as the site. Ayat are the Uthmani text matched word for word;
// adhkar and duas carry their hadith source.

private struct BioItem: Decodable, Hashable {
    let t: String; let k: String; let c: String; let src: String
    var isAyah: Bool { k == "ayah" }
}
private struct BioFile: Decodable { let items: [BioItem] }

struct BioPhrasesView: View {
    private static let items: [BioItem] = {
        guard let url = Bundle.main.url(forResource: "bio_data", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(BioFile.self, from: d) else { return [] }
        return f.items
    }()
    private static let decors: [(String, String)] = [("", "بدون زخرفة"), ("🤍|🤍", "🤍"), ("✨|✨", "✨"), ("『|』", "『 』"), ("۞|۞", "۞"), ("🌿|🌿", "🌿")]
    private var cats: [String] {
        var out = ["الكل", "من القرآن", "أذكار وأدعية"]
        for x in Self.items where !out.contains(x.c) { out.append(x.c) }
        return out
    }
    @State private var filter = "الكل"
    @State private var decor = ""
    @State private var withSource = false
    @State private var copied: BioItem?

    private func output(_ x: BioItem) -> String {
        var t = x.isAyah ? "﴿\(x.t)﴾" : x.t
        if !decor.isEmpty, !x.isAyah {
            let p = decor.split(separator: "|").map(String.init)
            t = p[0] + " " + t + " " + p[1]
        }
        if withSource { t += " (\(x.src))" }
        return t
    }

    private var shown: [BioItem] {
        Self.items.filter { x in
            filter == "الكل" || (filter == "من القرآن" && x.isAyah) || (filter == "أذكار وأدعية" && !x.isAyah) || filter == x.c
        }
    }

    var body: some View {
        List {
            ToolHeadSection(id: "bio")
            Group {
                Section {
                    Text("اختر عبارة واضغط نسخ وألصقها في بايو انستقرام أو تيك توك أو حالة واتساب. كل آية بنصها ومكانها في المصحف، وكل ذكر مع رقم الحديث.")
                        .font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    chips(cats, selected: filter) { filter = $0 }
                    chips(Self.decors.map(\.1), selected: Self.decors.first { $0.0 == decor }?.1 ?? "") { label in
                        decor = Self.decors.first { $0.1 == label }?.0 ?? ""
                    }
                    Toggle("انسخ المصدر معها", isOn: $withSource).font(.ui(.subheadline)).tint(Brand.primaryInk)
                }
                ForEach(shown, id: \.self) { x in row(x) }
                Section {
                    Text("الزخرفة تضاف للأذكار فقط، وتبقى الآيات بين القوسين ﴿ ﴾ كما هي احتراما لنص القرآن.")
                        .font(.ui(.footnote)).foregroundStyle(Brand.muted)
                }
            }.listRowBackground(Brand.surface)
        }
        .brandScreen()
        .navigationTitle("عبارات للبايو")
    }

    private func chips(_ list: [String], selected: String, pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(list, id: \.self) { c in
                    Button { pick(c) } label: {
                        Text(c).font(.ui(.subheadline, .semibold)).lineLimit(1).fixedSize()
                            .padding(.horizontal, 14).frame(minHeight: 38)
                            .foregroundStyle(c == selected ? Color.white : Brand.ink)
                            .background(Capsule().fill(c == selected ? Brand.primaryInk : Brand.tint))
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func row(_ x: BioItem) -> some View {
        let text = output(x)
        let n = text.count
        let fit = n <= 80 ? "تيك توك وانستقرام" : n <= 150 ? "انستقرام" : "طويل للبايو"
        return Section {
            VStack(spacing: 10) {
                Text(x.isAyah ? "﴿\(x.t)﴾" : x.t)
                    .font(x.isAyah ? .custom(ContentLibrary.mushafFont, size: 22, relativeTo: .body) : .custom("Amiri", size: 19, relativeTo: .body))
                    .lineSpacing(8).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                HStack {
                    Text(x.src).font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Brand.goldSoft))
                    Spacer()
                    Text("\(Num.int(n)) حرف · \(fit)").font(.ui(.caption)).foregroundStyle(n > 150 ? .red : Brand.muted)
                }
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = text; copied = x
                    } label: {
                        Label(copied == x ? "تم النسخ" : "نسخ", systemImage: copied == x ? "checkmark" : "doc.on.doc")
                            .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
                    }
                    .buttonStyle(.borderedProminent).tint(Brand.primaryInk)
                    ShareLink(item: text) {
                        Label("مشاركة", systemImage: "square.and.arrow.up").font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: Brand.minTap)
                    }
                    .buttonStyle(.bordered).tint(Brand.primaryInk)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
