import SwiftUI
import AyatDesign

/// «الختمة الجماعية» (same as Android): names in, the 30 juz split between them in order, one message
/// shares who reads what, and each juz is ticked when its reader is done. All on the device.
struct GroupKhatma: Codable, Equatable {
    var title: String
    var names: [String]
    var done: Set<Int>

    func split() -> [(name: String, juz: ClosedRange<Int>)] {
        let n = min(names.count, 30)
        guard n > 0 else { return [] }
        let base = 30 / n, extra = 30 % n
        var start = 1
        return (0..<n).map { i in
            let count = base + (i < extra ? 1 : 0)
            defer { start += count }
            return (names[i], start...(start + count - 1))
        }
    }

    var message: String {
        var s = "ختمة جماعية: \(title)\n"
        for p in split() { s += "\(p.name): " + (p.juz.count == 1 ? "الجزء \(p.juz.lowerBound)" : "الأجزاء \(p.juz.lowerBound) إلى \(p.juz.upperBound)") + "\n" }
        return s + "\nاقرأ وردك من تطبيق آيات تتلى"
    }

    static let key = "group.khatma"
    static func load() -> GroupKhatma? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(GroupKhatma.self, from: $0) }
    }
    static func save(_ g: GroupKhatma?) {
        if let g, let d = try? JSONEncoder().encode(g) { UserDefaults.standard.set(d, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
    }
}

struct GroupKhatmaView: View {
    @State private var group = GroupKhatma.load()
    @State private var title = "ختمة العائلة"
    @State private var name = ""
    @State private var names: [String] = []

    private func update(_ g: GroupKhatma?) { group = g; GroupKhatma.save(g) }

    var body: some View {
        List {
            if let g = group {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(g.title).font(.ui(.title3, .bold))
                        Text("تم \(Num.int(g.done.count)) من \(Num.int(30)) جزء").font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                        ProgressView(value: Double(g.done.count), total: 30).tint(Brand.green)
                        if g.done.count == 30 { Text("تمت الختمة، تقبل الله منكم").font(.ui(.headline)).foregroundStyle(Brand.primaryInk) }
                    }
                    ShareLink(item: g.message) { Label("أرسل التوزيع للمجموعة", systemImage: "square.and.arrow.up") }
                }
                ForEach(Array(g.split().enumerated()), id: \.offset) { _, p in
                    Section(p.name) {
                        ForEach(Array(p.juz), id: \.self) { j in
                            HStack {
                                Button {
                                    var n = g; if n.done.contains(j) { n.done.remove(j) } else { n.done.insert(j) }; update(n)
                                } label: {
                                    Label("الجزء \(Num.int(j))", systemImage: g.done.contains(j) ? "checkmark.circle.fill" : "circle")
                                }
                                .accessibilityValue(g.done.contains(j) ? "تم" : "لم يتم")
                                Spacer()
                                NavigationLink("اقرأ") { MushafReader(startPage: MushafMarks.pages(juz: j).0) }.fixedSize()
                            }
                        }
                    }
                }
            } else {
                Section {
                    Text("وزع أجزاء القرآن الثلاثين على أهلك أو أصحابك، وأرسل لهم رسالة فيها نصيب كل واحد.").font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    TextField("اسم الختمة", text: $title)
                }
                Section("المشاركون") {
                    HStack {
                        TextField("اسم المشارك", text: $name)
                        Button("أضف") { names.append(name.trimmingCharacters(in: .whitespaces)); name = "" }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || names.count >= 30)
                    }
                    ForEach(Array(names.enumerated()), id: \.offset) { i, n in Text("\(Num.int(i + 1)). \(n)") }
                        .onDelete { names.remove(atOffsets: $0) }
                }
                Section {
                    Button("وزع الأجزاء") { update(GroupKhatma(title: title, names: names, done: [])) }
                        .disabled(names.isEmpty || title.isEmpty)
                }
            }
        }
        .navigationTitle("الختمة الجماعية")
        .toolbar { if group != nil { Button("ختمة جديدة") { update(nil); names = [] } } }
    }
}
