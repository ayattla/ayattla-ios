import SwiftUI
import AyatDesign
import AyatCalc

/// Saved khatma plan (JSON in UserDefaults), shared with Library and the reminders.
enum KhatmaStore {
    static let key = "khatma.plan"

    static func load(_ raw: String) -> KhatmaPlan? {
        raw.isEmpty ? nil : try? JSONDecoder().decode(KhatmaPlan.self, from: Data(raw.utf8))
    }

    static func save(_ plan: KhatmaPlan?) -> String {
        guard let plan, let d = try? JSONEncoder().encode(plan) else { return "" }
        return String(decoding: d, as: UTF8.self)
    }

    static func surahName(atPage page: Int) -> String {
        let lib = ContentLibrary.shared
        return (try? lib.store?.page(page))?.first.flatMap { lib.surah($0.surah)?.shortName } ?? ""
    }
}

/// Khatma plan, per design/Khatma.dc.html and /tools/khatma.
struct KhatmaView: View {
    @AppStorage(KhatmaStore.key) private var raw = ""
    @State private var editing = false

    var body: some View {
        Group {
            if let plan = KhatmaStore.load(raw) {
                KhatmaProgressView(plan: plan, update: { raw = KhatmaStore.save($0) }, edit: { editing = true })
            } else {
                KhatmaSetup(initial: nil) { raw = KhatmaStore.save($0) }
            }
        }
        .navigationTitle("خطة الختمة")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: raw) { _, _ in Task { await Reminders.reschedule() } }
        .sheet(isPresented: $editing) {
            NavigationStack {
                KhatmaSetup(initial: KhatmaStore.load(raw)) { raw = KhatmaStore.save($0); editing = false }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { editing = false } }
                        ToolbarItem(placement: .destructiveAction) {
                            Button("حذف الخطة", role: .destructive) { raw = ""; editing = false }
                        }
                    }
                    .navigationTitle("تعديل الخطة")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

struct KhatmaSetup: View {
    static let presets = [3, 7, 10, 15, 20, 30, 60]
    let initial: KhatmaPlan?
    let done: (KhatmaPlan) -> Void

    @State private var days = 30
    @State private var start = Date()
    @State private var startPage = 1

    var body: some View {
        Form {
            Section {
                Picker("مدة الختمة", selection: $days) {
                    ForEach(Self.presets, id: \.self) { Text("\(Num.int($0)) يوما").tag($0) }
                }
                Stepper("أو حدد: \(Num.int(days)) يوما", value: $days, in: 1...365)
                DatePicker("تاريخ البدء", selection: $start, displayedComponents: .date)
                Stepper("أبدأ من صفحة \(Num.int(startPage))", value: $startPage, in: 1...KhatmaPlan.pages)
                if startPage > 1 {
                    Text(KhatmaStore.surahName(atPage: startPage)).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                let p = KhatmaPlan(days: days, startPage: startPage, startDate: start)
                Text("نحو \(Num.decimal(p.pagesPerDay)) صفحة يوميا، من صفحة \(Num.int(startPage)) إلى \(Num.int(KhatmaPlan.pages)).")
            }
            Section {
                Button(initial == nil ? "ابدأ الخطة" : "حفظ") {
                    var p = KhatmaPlan(days: days, startPage: startPage, startDate: start)
                    if let i = initial, i.days == days, i.startPage == startPage { p.completedDays = i.completedDays }
                    done(p)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Brand.minTap)
            }
        }
        .onAppear {
            if let i = initial { days = i.days; start = i.startDate; startPage = i.startPage }
        }
    }
}

struct KhatmaProgressView: View {
    let plan: KhatmaPlan
    let update: (KhatmaPlan) -> Void
    let edit: () -> Void

    var body: some View {
        let today = min(max(plan.day(on: Date()), 1), plan.days)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary(today)
                if let r = plan.range(day: today) { wird(day: today, r) }
                if let r = plan.range(day: today) { prayers(r) }
                daysGrid(today)
                groupKhatma
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("تعديل", action: edit) } }
    }

    private func summary(_ today: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ختمة في \(Num.int(plan.days)) يوما").font(.title3.weight(.semibold))
            Text("اليوم \(Num.int(today)) · \(Num.decimal(plan.pagesPerDay)) صفحة يوميا").font(.subheadline).opacity(0.9)
            Text("الختم المتوقع: \(plan.expectedEnd().formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Num.locale)))")
                .font(.footnote).opacity(0.9)
            ProgressView(value: Double(plan.completedDays.count), total: Double(plan.days))
                .tint(.white).padding(.top, 4)
                .accessibilityLabel("أنجزت \(Num.int(plan.completedDays.count)) من \(Num.int(plan.days)) يوما")
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [Brand.g0, Brand.primary], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func wird(day: Int, _ r: ClosedRange<Int>) -> some View {
        let isDone = plan.completedDays.contains(day)
        return VStack(alignment: .leading, spacing: 12) {
            Text("ورد اليوم").font(.headline)
            Text("من صفحة \(Num.int(r.lowerBound)) إلى \(Num.int(r.upperBound)) · \(KhatmaStore.surahName(atPage: r.lowerBound))")
                .font(.subheadline).foregroundStyle(Brand.muted)
            HStack(spacing: 10) {
                NavigationLink { MushafReader(startPage: r.lowerBound) } label: {
                    Text("ابدأ القراءة").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Brand.minTap)
                        .background(Brand.primary, in: Capsule())
                }
                Button { toggle(day) } label: {
                    Label("تم", systemImage: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.primaryInk)
                        .padding(.horizontal, 18).frame(minHeight: Brand.minTap)
                        .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                }
                .accessibilityLabel(isDone ? "ورد اليوم منجز" : "اجعل ورد اليوم منجزا")
            }
        }
        .padding(16)
        .card()
    }

    private func prayers(_ r: ClosedRange<Int>) -> some View {
        let parts = KhatmaPlan.splitOverPrayers(r)
        let names = [Prayer.fajr, .dhuhr, .asr, .maghrib, .isha].map(\.name)
        return VStack(alignment: .leading, spacing: 10) {
            Text("توزيع على الصلوات").font(.headline)
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    HStack {
                        Text(names[i])
                        Spacer()
                        if let p = parts[i] {
                            Text(p.count == 1 ? "ص \(Num.int(p.lowerBound))" : "ص \(Num.int(p.lowerBound))–\(Num.int(p.upperBound))")
                                .foregroundStyle(Brand.primaryInk)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: Brand.minTap)
                    .padding(.horizontal, 16)
                    if i < 4 { Divider().overlay(Brand.line) }
                }
            }
            .card()
        }
    }

    private func daysGrid(_ today: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("الأيام (\(Num.int(plan.completedDays.count)) / \(Num.int(plan.days)))").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(1...plan.days, id: \.self) { d in
                    let on = plan.completedDays.contains(d)
                    Button { toggle(d) } label: {
                        Text(Num.int(d))
                            .font(.footnote.weight(d == today ? .bold : .regular))
                            .foregroundStyle(on ? .white : .primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(on ? Brand.primary : Color.cardSurface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(d == today ? Brand.primary : Brand.line, lineWidth: d == today ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("اليوم \(Num.int(d))\(on ? "، منجز" : "")")
                }
            }
        }
    }

    private var groupKhatma: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ختمة جماعية").font(.headline)
                Text("وزع الأجزاء على الأهل والأصدقاء").font(.footnote).foregroundStyle(Brand.muted)
            }
            Spacer()
            Text("قريبا").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .card()
    }

    private func toggle(_ d: Int) {
        var p = plan
        if p.completedDays.contains(d) { p.completedDays.remove(d) } else { p.completedDays.insert(d) }
        update(p)
    }
}
