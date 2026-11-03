import SwiftUI
import AyatDesign

/// A personal note and a category for each saved ayah («آياتي المحفوظة», master prompt §5ي).
/// Stored on the device as JSON keyed "s:a"; removing the ayah from the favorites keeps nothing.
enum FavoriteNotes {
    static let key = "favorites.notes"

    struct Entry: Codable, Equatable {
        var note: String = ""
        var tag: String = ""
    }

    static func all(_ raw: String) -> [String: Entry] {
        (try? JSONDecoder().decode([String: Entry].self, from: Data(raw.utf8))) ?? [:]
    }

    static func id(_ p: RecitationPlayer.Position) -> String { "\(p.surah):\(p.ayah)" }

    static func setting(_ raw: String, _ p: RecitationPlayer.Position, _ e: Entry?) -> String {
        var d = all(raw)
        let clean = e.map { Entry(note: $0.note.trimmingCharacters(in: .whitespacesAndNewlines),
                                  tag: $0.tag.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let clean, !(clean.note.isEmpty && clean.tag.isEmpty) { d[id(p)] = clean } else { d[id(p)] = nil }
        guard let data = try? JSONEncoder().encode(d) else { return raw }
        return String(decoding: data, as: UTF8.self)
    }

    /// Categories in use, most used first, then alphabetical.
    static func tags(_ raw: String) -> [String] {
        let counts = all(raw).values.map(\.tag).filter { !$0.isEmpty }.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.keys.sorted { (counts[$0]!, $1) > (counts[$1]!, $0) }
    }
}

/// The saved ayat list in «مكتبتي»: filter by category, note under each ayah, edit from the row.
struct SavedAyatList: View {
    @AppStorage(Favorites.key) private var favorites = ""
    @AppStorage(FavoriteNotes.key) private var notesRaw = ""
    @State private var tag = ""
    @State private var editing: RecitationPlayer.Position?
    private let lib = ContentLibrary.shared

    var body: some View {
        let items = Favorites.list(favorites)
        let notes = FavoriteNotes.all(notesRaw)
        let tags = FavoriteNotes.tags(notesRaw)
        let shown = tag.isEmpty ? items : items.filter { notes[FavoriteNotes.id($0)]?.tag == tag }
        if items.isEmpty {
            EmptyState("لا آيات محفوظة", symbol: "heart", message: "اضغط على أي آية في المصحف ثم «أضف للمفضلة»")
        } else {
            VStack(spacing: 0) {
                if !tags.isEmpty {
                    CategorySelector([(id: "", title: "الكل")] + tags.map { (id: $0, title: $0) }, selection: $tag)
                        .padding(.vertical, 6)
                }
                List {
                    ForEach(shown) { p in
                        row(p, notes[FavoriteNotes.id(p)])
                            .listRowBackground(Brand.surface)
                            .swipeActions(edge: .leading) {
                                Button { editing = p } label: { Label("ملاحظة", systemImage: "square.and.pencil") }
                                    .tint(Brand.primary)
                            }
                            .contextMenu {
                                Button { editing = p } label: { Label("ملاحظة وتصنيف", systemImage: "square.and.pencil") }
                            }
                    }
                    .onDelete { idx in
                        for i in idx {
                            favorites = Favorites.toggled(favorites, shown[i])
                            notesRaw = FavoriteNotes.setting(notesRaw, shown[i], nil)
                        }
                    }
                }
                .brandScreen()
            }
            .sheet(item: $editing) { p in
                NoteEditor(position: p, entry: notes[FavoriteNotes.id(p)] ?? .init(), tags: tags) { e in
                    notesRaw = FavoriteNotes.setting(notesRaw, p, e)
                }
            }
        }
    }

    private func row(_ p: RecitationPlayer.Position, _ e: FavoriteNotes.Entry?) -> some View {
        let a = (try? lib.store?.ayat(surah: p.surah, from: p.ayah, to: p.ayah))?.first
        return NavigationLink { MushafReader(startPage: a?.page ?? 1, focus: p) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(QuranText.reference(p)).font(.ui(.caption)).foregroundStyle(Brand.primaryInk)
                    if let t = e?.tag, !t.isEmpty {
                        Text(t).font(.ui(.caption2, .medium)).foregroundStyle(Brand.goldInk)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Brand.goldSoft, in: Capsule())
                    }
                }
                Text(a?.textUthmani ?? "").font(.custom(ContentLibrary.mushafFont, size: 19, relativeTo: .body))
                    .lineLimit(3)
                if let n = e?.note, !n.isEmpty {
                    Label(n, systemImage: "note.text").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct NoteEditor: View {
    let position: RecitationPlayer.Position
    @State var entry: FavoriteNotes.Entry
    let tags: [String]
    let save: (FavoriteNotes.Entry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("ملاحظتك") {
                    TextField("اكتب ما تريد تذكره عن الآية", text: $entry.note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    TextField("مثال: للحفظ، للتدبر، للمشاركة", text: $entry.tag)
                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { t in
                                Button(t) { entry.tag = t }
                                    .font(.ui(.footnote, .medium))
                                    .padding(.horizontal, 12).frame(minHeight: 34)
                                    .background(entry.tag == t ? Brand.tint : Brand.surface, in: Capsule())
                                    .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                } header: { Text("التصنيف") }
            }
            .brandScreen()
            .navigationTitle(QuranText.reference(position))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("حفظ") { save(entry); dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
