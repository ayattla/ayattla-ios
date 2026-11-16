import SwiftUI
import UserNotifications
import AyatDesign
import AyatCalc

/// «مركز التنبيهات»: every reminder of the app in one place, the same rules as the Android app.
struct NotificationCenterView: View {
    @State private var config = NotifyConfig.load()
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var upcoming: [NotifyPlanner.Alert] = []
    @State private var log: [NotifyLog.Entry] = []
    @State private var expanded: Prayer?
    @State private var newTitle = ""
    @State private var newTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var newDays: Set<Int> = Set(1...7)
    @Environment(\.scenePhase) private var phase

    private let weekDays: [(Int, String)] = [(7, "السبت"), (1, "الأحد"), (2, "الاثنين"), (3, "الثلاثاء"), (4, "الأربعاء"), (5, "الخميس"), (6, "الجمعة")]

    var body: some View {
        Form {
            ToolHeadSection(id: "notifications")
            statusSection
            prayersSection
            Section("الأذكار") {
                toggle("أذكار الصباح", "بعد الفجر بـ \(Num.int(config.morningOffset)) دقيقة", \.morning)
                if config.morning { minutes("بعد الفجر بـ", [15, 30, 45, 60], \.morningOffset) }
                toggle("أذكار المساء", "بعد العصر بـ \(Num.int(config.eveningOffset)) دقيقة", \.evening)
                if config.evening { minutes("بعد العصر بـ", [15, 30, 45, 60], \.eveningOffset) }
                toggle("الأذكار بعد الصلاة", "بعد كل صلاة بـ \(Num.int(config.afterPrayerDelay)) دقيقة (وبعد الإقامة إن حددتها)", \.afterPrayer)
                if config.afterPrayer { minutes("بعد الصلاة بـ", [5, 10, 15, 20], \.afterPrayerDelay) }
                toggle("أذكار النوم", clock(config.sleepAt), \.sleep)
                if config.sleep { time("الوقت", \.sleepAt) }
                toggle("أذكار الاستيقاظ", "قبل الفجر بعشرين دقيقة", \.wake)
                toggle("الاستغفار والتسبيح", clock(config.istighfarAt), \.istighfar)
                if config.istighfar { time("الوقت", \.istighfarAt) }
            }
            Section("القرآن") {
                toggle("آية اليوم", clock(config.ayahAt), \.ayah)
                if config.ayah { time("الوقت", \.ayahAt) }
                toggle("ورد الختمة", "\(clock(config.khatmaAt)) · عند وجود خطة ختمة ولم تُتم ورد اليوم", \.khatma)
                if config.khatma { time("الوقت", \.khatmaAt) }
                toggle("الحفظ والمراجعة", "\(clock(config.hifzAt)) · عند وجود خطة حفظ", \.hifz)
                if config.hifz { time("الوقت", \.hifzAt) }
            }
            Section("الجمعة والصيام") {
                toggle("سورة الكهف يوم الجمعة", clock(config.fridayAt), \.friday)
                if config.friday { time("الوقت", \.fridayAt) }
                toggle("صيام الاثنين والخميس", "ليلة الاثنين وليلة الخميس \(clock(config.fastingAt))", \.fasting)
                toggle("الأيام البيض", "ليلة 13 و14 و15 من الشهر الهجري", \.whiteDays)
                if config.fasting || config.whiteDays { time("وقت التذكير", \.fastingAt) }
            }
            personalSection
            Section {
                toggle("الهدوء الليلي", "\(clock(config.quietFrom)) – \(clock(config.quietTo)) · لا يمنع تنبيهات الصلاة", \.quiet)
                if config.quiet { time("من", \.quietFrom); time("إلى", \.quietTo) }
                minutes("زر «أجّل» في الإشعار", [5, 10, 15, 30], \.snooze)
            } header: { Text("الهدوء الليلي والتأجيل") }
            Section("المجدولة القادمة") {
                if upcoming.isEmpty { Text("فعّل تنبيها لتظهر مواعيده هنا.").foregroundStyle(.secondary) }
                ForEach(upcoming.prefix(15), id: \.id) { a in
                    HStack { Text(a.title); Spacer(); Text(a.date, format: .dateTime.weekday(.abbreviated).hour().minute()).foregroundStyle(.secondary) }
                }
            }
            Section("سجل التنبيهات") {
                if log.isEmpty { Text("لم يصل أي تنبيه بعد.").foregroundStyle(.secondary) }
                ForEach(log.prefix(20), id: \.id) { e in
                    HStack { Text(e.title); Spacer(); Text(e.date, format: .dateTime.day().month().hour().minute()).foregroundStyle(.secondary) }
                }
            }
            Section {
                Text("تُجدول التنبيهات على جهازك ولا تحتاج بقاء التطبيق مفتوحا. يسمح iOS بأربعة وستين تنبيها مجدولا، فيُجدول التطبيق أقربها ويجدد الجدولة كلما فتحته.")
                    .font(.ui(.footnote)).foregroundStyle(.secondary)
            }
        }
        .brandScreen()
        .navigationTitle("مركز التنبيهات")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .onChange(of: config) { _, c in
            c.save()
            Task { await Reminders.reschedule(); await refresh() }
        }
        .onChange(of: phase) { _, p in if p == .active { Task { await refresh() } } }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            if let next = upcoming.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("التالي: \(next.title)").font(.ui(.headline)).foregroundStyle(Brand.primaryInk)
                    Text(next.date, format: .dateTime.weekday(.wide).hour().minute()).font(.ui(.footnote)).foregroundStyle(.secondary)
                }
            } else {
                Text("لا توجد تنبيهات مجدولة").font(.ui(.headline))
            }
            HStack {
                Text(status == .authorized || status == .provisional ? "✓ إذن الإشعارات ممنوح" : "✗ إذن الإشعارات غير ممنوح")
                    .foregroundStyle(status == .authorized || status == .provisional ? Brand.primaryInk : Brand.goldInk)
                Spacer()
                if status == .notDetermined {
                    Button("اسمح") { Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]); await refresh() } }
                } else if status == .denied {
                    Button("الإعدادات") { if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) } }
                }
            }
            Button("تنبيه تجريبي (بعد خمس ثوان)") { Task { await ensureAuthorized(); await Reminders.test() } }
        }
    }

    private var prayersSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { NotifyConfig.fivePrayers.allSatisfy { config.alert($0).on } },
                set: { v in for p in NotifyConfig.fivePrayers { var a = config.alert(p); a.on = v; config.setAlert(p, a) }; Task { await ensureAuthorized() } }
            )) {
                VStack(alignment: .leading) {
                    Text("كل الصلوات الخمس")
                    Text("الشروق ليس صلاة فلا يُرسل له تنبيه").font(.ui(.caption)).foregroundStyle(.secondary)
                }
            }
            ForEach(NotifyConfig.fivePrayers) { p in
                let a = config.alert(p)
                Toggle(isOn: Binding(get: { a.on }, set: { v in var x = a; x.on = v; config.setAlert(p, x); Task { await ensureAuthorized() } })) {
                    VStack(alignment: .leading) {
                        Text("صلاة \(p.name)")
                        Text(summary(a)).font(.ui(.caption)).foregroundStyle(.secondary)
                    }
                }
                Button(expanded == p ? "إخفاء الإعدادات" : "إعدادات \(p.name)") { expanded = expanded == p ? nil : p }
                    .font(.ui(.footnote))
                if expanded == p {
                    Toggle("صامت (بلا صوت)", isOn: Binding(get: { a.silent }, set: { v in var x = a; x.silent = v; config.setAlert(p, x) }))
                    Picker("تذكير قبل الصلاة", selection: Binding(get: { a.before }, set: { v in var x = a; x.before = v; config.setAlert(p, x) })) {
                        ForEach([0, 5, 10, 15, 20, 30], id: \.self) { Text($0 == 0 ? "بدون" : "\(Num.int($0)) د").tag($0) }
                    }
                    Picker("تذكير الإقامة بعد الأذان", selection: Binding(get: { a.iqama }, set: { v in var x = a; x.iqama = v; config.setAlert(p, x) })) {
                        ForEach([0, 10, 15, 20, 25, 30], id: \.self) { Text($0 == 0 ? "بدون" : "\(Num.int($0)) د").tag($0) }
                    }
                }
            }
            NavigationLink("طريقة حساب المواقيت والتعديل اليدوي") { PrayerCalcView() }
        } header: { Text("الصلوات") } footer: {
            Text("يستخدم التنبيه صوت الإشعار في جهازك. لا يشغّل iOS أذانا كاملا من الإشعار.")
        }
    }

    private var personalSection: some View {
        Section("تذكيراتي") {
            ForEach(config.personal) { r in
                HStack {
                    VStack(alignment: .leading) {
                        Text(r.title)
                        Text("\(clock(r.minute)) · \(r.days.count == 7 ? "كل يوم" : weekDays.filter { r.days.contains($0.0) }.map(\.1).joined(separator: "، "))")
                            .font(.ui(.caption)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("حذف", role: .destructive) { config.personal.removeAll { $0.id == r.id } }
                }
            }
            TextField("عنوان التذكير، مثل: قيام الليل", text: $newTitle)
            DatePicker("الوقت", selection: $newTime, displayedComponents: .hourAndMinute)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(weekDays, id: \.0) { d in
                        Button(d.1) { if newDays.contains(d.0) { newDays.remove(d.0) } else { newDays.insert(d.0) } }
                            .buttonStyle(.bordered).tint(newDays.contains(d.0) ? Brand.green : .secondary)
                    }
                }
            }
            Button("أضف التذكير") {
                let c = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                config.personal.append(.init(id: UUID().uuidString, title: newTitle.trimmingCharacters(in: .whitespaces),
                                             minute: c.hour! * 60 + c.minute!, days: newDays))
                newTitle = ""
                Task { await ensureAuthorized() }
            }
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty || newDays.isEmpty)
        }
    }

    // MARK: Rows

    private func toggle(_ title: String, _ sub: String, _ key: WritableKeyPath<NotifyConfig, Bool>) -> some View {
        Toggle(isOn: Binding(get: { config[keyPath: key] }, set: { v in config[keyPath: key] = v; if v { Task { await ensureAuthorized() } } })) {
            VStack(alignment: .leading) {
                Text(title)
                Text(sub).font(.ui(.caption)).foregroundStyle(.secondary)
            }
        }
    }

    private func minutes(_ title: String, _ options: [Int], _ key: WritableKeyPath<NotifyConfig, Int>) -> some View {
        Picker(title, selection: Binding(get: { config[keyPath: key] }, set: { config[keyPath: key] = $0 })) {
            ForEach(options, id: \.self) { Text("\(Num.int($0)) د").tag($0) }
        }
    }

    private func time(_ title: String, _ key: WritableKeyPath<NotifyConfig, Int>) -> some View {
        DatePicker(title, selection: Binding(
            get: { Calendar.current.date(bySettingHour: config[keyPath: key] / 60, minute: config[keyPath: key] % 60, second: 0, of: Date()) ?? Date() },
            set: { d in let c = Calendar.current.dateComponents([.hour, .minute], from: d); config[keyPath: key] = c.hour! * 60 + c.minute! }
        ), displayedComponents: .hourAndMinute)
    }

    private func summary(_ a: PrayerAlertSetting) -> String {
        var s = a.silent ? "صامت" : "صوت التنبيه"
        if a.before > 0 { s += " · قبلها \(Num.int(a.before)) د" }
        if a.iqama > 0 { s += " · الإقامة \(Num.int(a.iqama)) د" }
        return s
    }

    private func clock(_ minute: Int) -> String {
        let d = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return d.formatted(.dateTime.hour().minute())
    }

    private func ensureAuthorized() async {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        await refresh()
    }

    private func refresh() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        upcoming = Reminders.upcoming()
        await NotifyLog.collect()
        log = NotifyLog.all()
    }
}

/// «حساب مواقيت الصلاة»: method, Asr school and minute adjustments for every screen and notification.
struct PrayerCalcView: View {
    @AppStorage(PrayerCalc.methodKey) private var method = "auto"
    @AppStorage(PrayerCalc.hanafiKey) private var hanafi = false
    @AppStorage("prayer.city") private var cityName = PrayerCity.all[0].name
    @State private var adjust: [Prayer: Int] = PrayerCalc.adjust()

    private var city: PrayerCity { PrayerCity.named(cityName) ?? PrayerCity.all[0] }

    var body: some View {
        let zone = TimeZone(identifier: city.zone) ?? .current
        let t = PrayerCalc.times(on: Date(), lat: city.lat, lng: city.lng, zone: zone, method: city.method)
        Form {
            Section("\(city.name) · اليوم") {
                ForEach(Prayer.allCases) { p in
                    HStack { Text(p.name).foregroundStyle(p == .sunrise ? .secondary : .primary); Spacer(); Text(Num.time(t.hours(p))) }
                }
            }
            Section {
                Picker("الطريقة", selection: $method) {
                    Text("تلقائي (مثل الموقع)").tag("auto")
                    ForEach(PrayerTimes.Method.choices, id: \.id) { Text($0.name).tag($0.id) }
                }
            } header: { Text("طريقة الحساب") } footer: {
                Text("«تلقائي»: أم القرى في مدن السعودية (العشاء بعد المغرب بـ 90 دقيقة، و120 في رمضان)، وطريقة كل بلد كما في موقع آيات تتلى.")
            }
            Section("صلاة العصر") {
                Picker("المذهب", selection: $hanafi) {
                    Text("الجمهور (ظل المثل)").tag(false)
                    Text("الحنفي (ظل المثلين)").tag(true)
                }
                .pickerStyle(.inline).labelsHidden()
            }
            Section("التعديل اليدوي بالدقائق") {
                ForEach(Prayer.allCases) { p in
                    Stepper(value: Binding(get: { adjust[p] ?? 0 }, set: { v in
                        adjust[p] = v == 0 ? nil : v
                        UserDefaults.standard.set(v, forKey: PrayerCalc.adjustKey(p))
                    }), in: -30...30) {
                        HStack { Text(p.name); Spacer(); Text("\((adjust[p] ?? 0) > 0 ? "+" : "")\(Num.int(adjust[p] ?? 0))").foregroundStyle(Brand.primaryInk) }
                    }
                }
                Button("إعادة الضبط الافتراضي") {
                    method = "auto"; hanafi = false
                    for p in Prayer.allCases { UserDefaults.standard.removeObject(forKey: PrayerCalc.adjustKey(p)) }
                    adjust = [:]
                }
            }
            Section {
                Text("الحساب فلكي على جهازك بمعادلات موقع آيات تتلى نفسها، وتتأثر المواقيت والتنبيهات والصفحة الرئيسية بهذه الإعدادات معا.")
                    .font(.ui(.footnote)).foregroundStyle(.secondary)
            }
        }
        .brandScreen()
        .navigationTitle("حساب مواقيت الصلاة")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await Reminders.reschedule() } }
    }
}
