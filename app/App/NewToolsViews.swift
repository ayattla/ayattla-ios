import SwiftUI
import AyatDesign
import AyatContent

/// Pure sums for the expiations calculator (unit-tested).
enum Kaffarah {
    enum Kind: String, CaseIterable, Identifiable {
        case oath, fidya, ramadan
        var id: String { rawValue }
        var title: String {
            switch self { case .oath: "كفارة اليمين"; case .fidya: "فدية الصيام"; case .ramadan: "كفارة رمضان" }
        }
    }
    /// Meals owed: ten poor per broken oath, one per day of fidya, sixty for the Ramadan expiation.
    static func meals(_ k: Kind, _ count: Int) -> Int {
        switch k { case .oath: 10 * count; case .fidya: count; case .ramadan: 60 * count }
    }
}

private func money(_ v: Double) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 2; f.locale = Locale(identifier: "ar")
    return f.string(from: NSNumber(value: v)) ?? "\(v)"
}

/// An ayah from the pack with its reference (the evidence under a calculator).
private struct EvidenceAyah: View {
    let surah: Int, from: Int, to: Int
    private let lib = ContentLibrary.shared
    var body: some View {
        let ayat = (try? lib.store?.ayat(surah: surah, from: from, to: to)) ?? []
        VStack(spacing: 6) {
            Text(ayat.map { $0.textUthmani + " " + QuranText.marker($0.ayah) }.joined(separator: " "))
                .font(.custom(ContentLibrary.mushafFont, size: 19, relativeTo: .body)).lineSpacing(8)
            Text("سورة \(lib.surah(surah)?.shortName ?? "") · \(Num.int(from))\(from == to ? "" : "–\(Num.int(to))")")
                .font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
        }
        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}

/// «حاسبة الكفارات»: oath, fidya and the Ramadan expiation, as meals and money, with the evidence.
struct KaffarahView: View {
    @State private var kind = Kaffarah.Kind.oath
    @State private var count = 1
    @State private var meal = ""

    var body: some View {
        let meals = Kaffarah.meals(kind, count)
        let price = Double(meal) ?? 0
        Form {
            ToolHeadSection(id: "kaffarah")
            Section {
                Picker("النوع", selection: $kind) { ForEach(Kaffarah.Kind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Stepper("\(kind == .oath ? "عدد الأيمان" : "عدد الأيام"): \(Num.int(count))", value: $count, in: 1...3000)
                TextField("قيمة الوجبة الواحدة (اختياري)", text: $meal).keyboardType(.decimalPad)
            }
            Section("المطلوب") {
                VStack(spacing: 6) {
                    Text("إطعام \(Num.int(meals)) مسكينا").font(.ui(.title2, .bold)).foregroundStyle(Brand.primaryInk)
                    if price > 0 { Text("قرابة \(money(Double(meals) * price))").font(.ui(.headline)).foregroundStyle(Brand.goldInk) }
                    Text(note).font(.ui(.subheadline)).foregroundStyle(Brand.ink)
                }
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            Section("الدليل") {
                switch kind {
                case .oath: EvidenceAyah(surah: 5, from: 89, to: 89)
                case .fidya: EvidenceAyah(surah: 2, from: 184, to: 184)
                case .ramadan:
                    VStack(spacing: 4) {
                        Text("حديث أبي هريرة رضي الله عنه في الرجل الذي وقع على امرأته في رمضان").font(.ui(.subheadline))
                        Text("رواه البخاري (1936) ومسلم (1111)").font(.ui(.caption, .semibold)).foregroundStyle(Brand.primaryInk)
                    }
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
            }
            Section { Text("تقدير أولي للمساعدة، والحالات الخاصة يُسأل عنها أهل العلم.").font(.ui(.caption)).foregroundStyle(Brand.muted) }
        }
        .brandScreen()
        .navigationTitle("حاسبة الكفارات")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var note: String {
        switch kind {
        case .oath: "أو كسوة عشرة مساكين أو عتق رقبة، فمن لم يجد فصيام ثلاثة أيام عن كل يمين."
        case .fidya: "لمن لا يستطيع الصيام عجزا دائما كالكبير والمريض الذي لا يرجى برؤه: إطعام مسكين عن كل يوم."
        case .ramadan: "على الترتيب: عتق رقبة، فإن لم يجد فصيام شهرين متتابعين، فإن لم يستطع فإطعام ستين مسكينا، مع قضاء اليوم."
        }
    }
}

/// «زكاة العملات الرقمية»: holdings × price, against the gold nisab; 2.5% when it is reached.
struct CryptoZakatView: View {
    struct Row: Identifiable { let id = UUID(); var amount = ""; var price = "" }
    @State private var rows = [Row(), Row()]
    @State private var gold = ""
    @State private var debts = ""

    var body: some View {
        let total = rows.reduce(0.0) { $0 + (Double($1.amount) ?? 0) * (Double($1.price) ?? 0) } - (Double(debts) ?? 0)
        let nisab = (Double(gold) ?? 0) * 85
        let reached = nisab > 0 && total >= nisab
        Form {
            ToolHeadSection(id: "crypto-zakat")
            Section {
                VStack(spacing: 4) {
                    Text(reached ? "الزكاة الواجبة" : nisab == 0 ? "أدخل سعر جرام الذهب لمعرفة النصاب" : "لم يبلغ المال النصاب").font(.ui(.subheadline, .semibold))
                    Text(money(reached ? total * 0.025 : 0)).font(.ui(.largeTitle, .bold)).foregroundStyle(Brand.primaryInk)
                    Text("القيمة الصافية \(money(max(0, total))) · النصاب \(money(nisab))").font(.ui(.caption)).foregroundStyle(Brand.muted)
                }
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            Section("النصاب") { TextField("سعر جرام الذهب عيار 24 (النصاب 85 جراما)", text: $gold).keyboardType(.decimalPad) }
            ForEach($rows) { $r in
                Section("العملة \(Num.int((rows.firstIndex { $0.id == r.id } ?? 0) + 1))") {
                    TextField("الكمية", text: $r.amount).keyboardType(.decimalPad)
                    TextField("السعر للوحدة", text: $r.price).keyboardType(.decimalPad)
                }
            }
            Section {
                if rows.count < 10 { Button("أضف عملة") { rows.append(Row()) } }
                TextField("ديون حالّة عليك (اختياري)", text: $debts).keyboardType(.decimalPad)
            } footer: {
                Text("تُحسب العملات الرقمية المملوكة للتجارة أو الادخار بقيمتها يوم وجوب الزكاة بعد حولان الحول، وفيها ربع العشر (2.5٪). تقدير أولي، والحالات الخاصة يُسأل عنها أهل العلم.")
            }
        }
        .brandScreen()
        .navigationTitle("زكاة العملات الرقمية")
        .navigationBarTitleDisplayMode(.inline)
    }
}
