import SwiftUI
import UserNotifications
import AyatDesign

/// Stored preferences. Keys are shared with the rest of the app through @AppStorage.
enum Prefs {
    static let reciter = "settings.reciter"
    static let translation = "settings.translation"
    static let fontScale = "settings.fontScale"
    static let appearance = "settings.appearance"
    static let notifyAzkar = "notify.azkar"
    static let notifyDailyAyah = "notify.dailyAyah"
    static let notifyKhatma = "notify.khatma"
    static let onboardingDone = "onboarding.done"

    static let defaultReciter = Catalog.reciters[0].id
}

/// Mushaf font scale, same steps as FONT_SCALES on the site (s 0.85, m 1.0, l 1.15).
enum FontScale: String, CaseIterable, Identifiable {
    case s, m, l
    var id: String { rawValue }
    var title: String {
        switch self {
        case .s: "صغير"
        case .m: "متوسط"
        case .l: "كبير"
        }
    }
    var factor: Double {
        switch self {
        case .s: 0.85
        case .m: 1.0
        case .l: 1.15
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "تلقائي"
        case .light: "فاتح"
        case .dark: "داكن"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Settings, per design/Settings.dc.html.
struct SettingsView: View {
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @AppStorage(Prefs.translation) private var translation = ""
    @AppStorage(Prefs.fontScale) private var fontScale = FontScale.m.rawValue
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(Prefs.notifyAzkar) private var notifyAzkar = false
    @AppStorage(Prefs.notifyDailyAyah) private var notifyDailyAyah = false
    @AppStorage(Prefs.notifyKhatma) private var notifyKhatma = false
    @State private var notificationsDenied = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Form {
Group {
            Section {
                HStack(spacing: Brand.Space.m) {
                    Image("LogoFull").resizable().scaledToFit().frame(width: 54, height: 54)
                        .padding(6).background(Brand.goldSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("آيات تتلى").font(.ui(.headline))
                        Text("مجاني بالكامل · بلا حساب · يعمل دون إنترنت").font(.ui(.caption)).foregroundStyle(Brand.muted)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("القراءة والاستماع") {
                NavigationLink {
                    ReciterPicker(selection: $reciter)
                } label: {
                    LabeledContent { Text(Catalog.reciter(reciter)?.name ?? "") } label: { row("القارئ المفضل", "headphones", 0) }
                }
                Picker(selection: $translation) {
                    ForEach(Catalog.translations) { Text($0.name).tag($0.id) }
                } label: { row("الترجمة", "character.book.closed", 1) }
                .pickerStyle(.navigationLink)
                fontScalePicker
            }

            Section("المظهر") {
                AppearancePicker(selection: $appearance)
                    .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
            }

            Section {
                Toggle(isOn: notify($notifyAzkar)) { row("أذكار الصباح والمساء", "sunrise", 2) }
                Toggle(isOn: notify($notifyDailyAyah)) { row("آية اليوم", "book", 3) }
                Toggle(isOn: notify($notifyKhatma)) { row("ورد الختمة", "checkmark.circle", 4) }
            } header: {
                Text("التنبيهات")
            } footer: {
                Text("أذكار الصباح بعد الفجر بنصف ساعة، والمساء بعد العصر بنصف ساعة، حسب مدينتك في المواقيت. آية اليوم الساعة ٩ صباحا، وورد الختمة الساعة ٨ مساء ما دامت لديك خطة.")
            }

            Section("عن التطبيق") {
                NavigationLink { LicensesView() } label: { row("مصادر المحتوى والتراخيص", "doc.text", 0) }
                NavigationLink { PrivacyView() } label: { row("الخصوصية", "lock.shield", 1) }
                LabeledContent { Text(Self.versionText()) } label: { row("الإصدار", "info.circle", 2) }
                LabeledContent { Text(Self.contentText(nil)) } label: { row("حزمة المحتوى", "shippingbox", 3) }
            }
        
}.listRowBackground(Brand.surface)
}
        .labeledContentStyle(AdaptiveLabeledContentStyle())
        .tint(Brand.primary)
        .brandScreen()
        .navigationTitle("الإعدادات")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: notifyAzkar) { _, _ in Task { await Reminders.reschedule() } }
        .onChange(of: notifyDailyAyah) { _, _ in Task { await Reminders.reschedule() } }
        .onChange(of: notifyKhatma) { _, _ in Task { await Reminders.reschedule() } }
        .alert("التنبيهات غير مسموحة", isPresented: $notificationsDenied) {
            Button("فتح الإعدادات") { openSystemSettings() }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("اسمح للتطبيق بإرسال التنبيهات من إعدادات الجهاز")
        }
    }

    /// A settings row label with a small gradient icon tile, as in the iOS Settings app (v3).
    private func row(_ title: String, _ symbol: String, _ tile: Int) -> some View {
        Label {
            Text(title)
        } icon: {
            IconTile(symbol, style: .gradient(tile), size: 30)
        }
        .labelStyle(SettingsRowLabelStyle())
    }

    /// Turning a reminder on asks for notification permission first; if refused the toggle stays off.
    private func notify(_ value: Binding<Bool>) -> Binding<Bool> {
        Binding {
            value.wrappedValue
        } set: { on in
            guard on else { value.wrappedValue = false; return }
            Task { @MainActor in
                let granted = await Self.requestNotifications()
                value.wrappedValue = granted
                notificationsDenied = !granted
            }
        }
    }

    static func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// App version with Arabic-Indic digits, isolated left-to-right so "١.٠.٠" keeps its order.
    static func versionText(bundle: Bundle = .main) -> String {
        let v = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "\u{2066}\(Num.digits(v))\u{2069}"
    }

    /// Content-pack version, or that it has not been downloaded yet.
    static func contentText(_ version: String?) -> String {
        version.map { "\u{2066}\(Num.digits($0))\u{2069}" } ?? "غير منزلة"
    }
}

struct AppearancePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Appearance.allCases) { a in
                let on = selection == a.rawValue
                Button {
                    selection = a.rawValue
                } label: {
                    Text(a.title)
                        .font(.subheadline.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? Brand.primaryInk : .primary)
                        .frame(maxWidth: .infinity, minHeight: Brand.minTap)
                        .background(on ? Brand.tint : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct ReciterPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
Group {
            Section {
                ForEach(results) { r in
                    Button {
                        selection = r.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(r.name).foregroundStyle(.primary)
                            if r.wordHighlight {
                                Image(systemName: "star.fill").font(.ui(.caption2)).foregroundStyle(Brand.accent)
                                    .accessibilityLabel("يدعم تظليل الكلمات")
                            }
                            Spacer()
                            if r.id == selection { Image(systemName: "checkmark").foregroundStyle(Brand.primary) }
                        }
                        .frame(minHeight: Brand.minTap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(r.id == selection ? .isSelected : [])
                }
            } footer: {
                Text("★ يدعم تظليل الكلمات في صانع المقاطع")
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("القارئ المفضل")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "ابحث عن قارئ")
    }

    private var results: [Catalog.Reciter] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? Catalog.reciters : Catalog.reciters.filter { $0.name.localizedStandardContains(q) }
    }
}

/// Summary of docs/CONTENT_AND_LICENSES.md for users.
struct LicensesView: View {
    private let rows: [(String, String)] = [
        ("النص القرآني", "Tanzil برواية حفص بالرسم العثماني، دون تعديل مع ذكر المصدر"),
        ("التفسير الميسر", "مجمع الملك فهد لطباعة المصحف الشريف عبر AlQuran Cloud"),
        ("الترجمات", "AlQuran Cloud، ولكل ترجمة رخصتها"),
        ("التلاوات", "EveryAyah"),
        ("توقيتات الكلمات", "Quran.com من Quran Foundation"),
        ("الأذكار", "أبواب حصن المسلم"),
        ("الأحاديث وأحكامها", "موسوعة الأحاديث النبوية (HadeethEnc)"),
        ("الخلفيات", "Pixabay، ومرسومة خصيصا للتطبيق"),
        ("الخطوط", "Amiri Quran وIBM Plex Sans Arabic برخصة OFL 1.1"),
        ("المواقيت والقبلة والهجري والزكاة", "تحسب على جهازك"),
        ("المساجد القريبة", "خرائط Apple"),
    ]

    var body: some View {
        List {
Group {
            Section {
                ForEach(rows, id: \.0) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.0).font(.ui(.headline))
                        Text(r.1).font(.ui(.subheadline)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                Text("لا يدخل أي محتوى في التطبيق قبل التحقق من رخصته، ويذكر مصدره دائما.")
            }
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("مصادر المحتوى والتراخيص")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    private let points: [(String, String)] = [
        ("person.crop.circle.badge.xmark", "لا حساب ولا تسجيل، ولا نجمع بيانات شخصية."),
        ("location", "يستخدم موقعك على جهازك فقط لحساب المواقيت والقبلة. البحث عن المساجد يتم عبر خرائط Apple."),
        ("iphone", "مشاريعك ومفضلتك وإعداداتك محفوظة على جهازك."),
        ("bell", "التنبيهات تجدول على جهازك ولا تمر بخوادمنا."),
    ]

    var body: some View {
        List(points, id: \.1) { p in
Group {
            Label {
                Text(p.1).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: p.0).foregroundStyle(Brand.primary)
            }
            .padding(.vertical, 6)
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("الخصوصية")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension SettingsView {
    /// A menu squeezes the title at accessibility text sizes; a navigation picker gives it the full row.
    @ViewBuilder fileprivate var fontScalePicker: some View {
        let picker = Picker("حجم خط المصحف", selection: $fontScale) {
            ForEach(FontScale.allCases) { Text($0.title).tag($0.rawValue) }
        }
        if typeSize.isAccessibilitySize { picker.pickerStyle(.navigationLink) } else { picker }
    }
}

/// Label and value side by side, stacked (label above value) at accessibility text sizes
/// so words are never broken across lines.
struct AdaptiveLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        AdaptiveLabeledRow(label: configuration.label, content: configuration.content)
    }
}

private struct AdaptiveLabeledRow<L: View, C: View>: View {
    let label: L
    let content: C
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                label
                content.foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                label
                Spacer(minLength: 12)
                content.foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        }
    }
}

/// Icon and title side by side with the app's spacing (the system style squeezes larger tiles).
struct SettingsRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            configuration.title.foregroundStyle(Brand.ink)
        }
    }
}
