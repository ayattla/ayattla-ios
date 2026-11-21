import SwiftUI
import AyatDesign

/// «يعمل بدون إنترنت» chip.
struct OfflineChip: View {
    let level: OfflineLevel
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: level.symbol).font(.system(size: 12, weight: .semibold))
            Text(level.label).font(.ui(.caption, .semibold))
        }
        .foregroundStyle(level.color)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(level.color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Floating strip shown while there is no connection; opens the offline centre.
struct OfflinePill: View {
    var onOpen: () -> Void
    var onClose: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "icloud.slash").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(red: 0.91, green: 0.77, blue: 0.42))
            VStack(spacing: 1) {
                Text("أنت بدون إنترنت").font(.ui(.subheadline, .bold)).foregroundStyle(.white)
                Text("أغلب الأدوات تعمل الآن. اضغط لترى ما يعمل").font(.ui(.caption2)).foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                    .frame(width: 34, height: 34).contentShape(Rectangle())
            }
            .accessibilityLabel("إخفاء")
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 8)
        .background(Color(red: 0.08, green: 0.22, blue: 0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityAddTraits(.isButton)
    }
}

/// A tool cannot do this without internet: what still works and the way to the offline centre.
struct OfflineNotice: View {
    let title: String
    let message: String
    var action: String = "ما يعمل بدون إنترنت"
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.slash").font(.system(size: 24, weight: .semibold)).foregroundStyle(Brand.goldInk)
                .frame(width: 52, height: 52).background(Brand.goldInk.opacity(0.12), in: Circle())
            Text(title).font(.ui(.headline, .bold)).foregroundStyle(Brand.ink)
            Text(message).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
            NavigationLink { OfflineCenterView() } label: {
                Text(action).font(.ui(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered).tint(Brand.primaryInk)
        }
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
    }
}

/// On every tool page while offline: the level under the title, and for a tool that needs internet
/// a clear note at the top.
struct OfflineToolInset: ViewModifier {
    let id: String
    @State private var net = Net.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if !net.isOnline && id != "offline" {
                let level = OfflineTools.level(id)
                VStack(spacing: 8) {
                    OfflineChip(level: level)
                    if level == .online {
                        OfflineNotice(title: "هذه الأداة تحتاج اتصالا بالإنترنت",
                                      message: "ستعمل تلقائيا عند عودة الاتصال. أغلب أدوات التطبيق تعمل الآن بدون إنترنت.")
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
    }
}

/// A tool tile while offline: dimmed with a «cloud off» mark when the tool needs internet.
struct OfflineDim: ViewModifier {
    let tool: SiteTool
    @State private var net = Net.shared
    func body(content: Content) -> some View {
        let dim = !net.isOnline && tool.offlineLevel == .online
        content
            .opacity(dim ? 0.45 : 1)
            .overlay(alignment: .topTrailing) {
                if dim {
                    Image(systemName: "icloud.slash").font(.system(size: 11, weight: .bold)).foregroundStyle(Brand.muted)
                        .padding(4).background(Brand.surface, in: Circle()).offset(x: 4, y: -4)
                        .accessibilityLabel("يحتاج إنترنت")
                }
            }
    }
}

extension View {
    func offlineDim(_ tool: SiteTool) -> some View { modifier(OfflineDim(tool: tool)) }
}

/// «الاستخدام بدون إنترنت»: what works now, getting the app ready, recitations, space and settings.
struct OfflineCenterView: View {
    var from: String? = nil
    @State private var net = Net.shared
    @State private var prep = OfflinePrep.shared
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @AppStorage(RecitationDownloads.keepHeardKey) private var keepHeard = true
    @AppStorage(OfflinePrep.autoKey) private var auto = true
    @State private var confirmClear = false
    @State private var status = OfflinePrep.Status()

    private let juz = Array(78...114)

    var body: some View {
        let lib = ContentLibrary.shared
        let reciterName = Catalog.reciters.first { $0.id == reciter }?.name ?? ""
        let folder = lib.reciterFolders[reciter]
        ScrollView {
            VStack(spacing: 16) {
                header
                if let id = from, let t = SiteTool.tool(id), t.offlineLevel == .online, !net.isOnline {
                    Text("«\(t.title)» تحتاج اتصالا بالإنترنت. ستعمل تلقائيا عند عودة الاتصال، وهذه أدوات تعمل الآن بدلا منها.")
                        .font(.ui(.subheadline)).foregroundStyle(Brand.ink).padding().frame(maxWidth: .infinity)
                        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                SectionHeader("جهّز التطبيق", subtitle: "يحفظ على جهازك ما تحتاجه الأدوات")
                card {
                    row("الأحاديث الصحيحة والحسنة", status.hadith > 0 ? "\(Num.int(status.hadith)) حديثا محفوظا للتصفح والبحث والتحقق" : "لم تحفظ بعد")
                    row("التجويد ومعاني الكلمات", status.tajweed > 0 ? "\(Num.int(status.tajweed)) سورة بالتجويد و\(Num.int(status.words)) بمعاني الكلمات" : "جزء عم والسور المشهورة")
                    row("خلفيات البطاقات والحالات", status.images > 0 ? "\(Num.int(status.images)) صورة محفوظة" : "مختارات من المساجد والطبيعة والسماء")
                    if prep.running {
                        Text(prep.stage).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                        ProgressView(value: prep.progress).tint(Brand.primary)
                        Button("إيقاف", role: .cancel) { prep.cancel() }.font(.ui(.subheadline))
                    } else {
                        Button { prep.start() } label: {
                            Label(status.hadith > 0 ? "تحديث الملفات المحفوظة" : "جهّز التطبيق للعمل بدون إنترنت", systemImage: "arrow.down.circle.fill")
                                .font(.ui(.headline)).frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent).tint(Brand.primary).disabled(!net.isOnline)
                        if !net.isOnline { Text("يتطلب التجهيز اتصالا بالإنترنت.").font(.ui(.footnote)).foregroundStyle(Brand.muted) }
                    }
                    if let r = prep.lastResult { Text(r).font(.ui(.subheadline)).foregroundStyle(Brand.primaryInk) }
                }

                SectionHeader("التلاوات بدون إنترنت", subtitle: "ما تستمع إليه يحفظ تلقائيا")
                card {
                    row("السور المحمّلة", "\(bytes(status.recitations)) على جهازك")
                    row("ما استمعت إليه", "\(bytes(status.heard)) يعاد تشغيله بدون إنترنت")
                    if let folder {
                        Button { prep.downloadRecitations(folder: folder, reciterName: reciterName) } label: {
                            Text("حمّل جزء عم بصوت \(reciterName) (نحو \(Num.int(OfflinePrep.estimateMB(juz))) م.ب)")
                                .font(.ui(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent).tint(Brand.goldInk).disabled(!net.isOnline || prep.running)
                    }
                    NavigationLink { DownloadsView() } label: {
                        Text("اختر السور والقارئ").font(.ui(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered).tint(Brand.primaryInk)
                }

                ForEach(OfflineLevel.allCases, id: \.self) { level in
                    let tools = SiteTool.all.filter { $0.offlineLevel == level && $0.id != "offline" }
                    if !tools.isEmpty {
                        OfflineChip(level: level)
                        Text(level.hint).font(.ui(.footnote)).foregroundStyle(Brand.muted)
                        card {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 12) {
                                ForEach(tools) { t in
                                    NavigationLink { t.destination.onAppear { ToolUsage.record(t.id) } } label: {
                                        LauncherTile(t.shortTitle, symbol: t.symbol, style: .accent(t.accent))
                                    }
                                    .buttonStyle(.pressable)
                                    .offlineDim(t)
                                }
                            }
                        }
                    }
                }

                SectionHeader("الإعدادات والمساحة")
                card {
                    Toggle(isOn: $keepHeard) { setting("حفظ التلاوات التي أستمع إليها", "تعاد بدون إنترنت، حتى 600 م.ب") }.tint(Brand.primary)
                    Toggle(isOn: $auto) { setting("التحديث التلقائي على واي فاي", "مرة كل أسبوع، بدون التلاوات") }.tint(Brand.primary)
                    Text("المساحة المستعملة للملفات المحفوظة: \(bytes(status.total))").font(.ui(.subheadline)).foregroundStyle(Brand.ink)
                    Button(role: .destructive) { confirmClear = true } label: {
                        Label("حذف الملفات المحفوظة", systemImage: "trash").font(.ui(.subheadline)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(prep.running)
                    Text("لا يحذف السور المحمّلة ولا محفوظاتك وإعداداتك.").font(.ui(.footnote)).foregroundStyle(Brand.muted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(16)
        }
        .brandScreen()
        .navigationTitle("الاستخدام بدون إنترنت")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("حذف الملفات المحفوظة؟", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("حذف", role: .destructive) { prep.clearSaved() }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("الأحاديث والتجويد والمعاني والخلفيات وما استمعت إليه. تحفظ من جديد عند الاتصال.") }
        .task(id: prep.version) { status = prep.status() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: net.isOnline ? "checkmark.icloud" : "icloud.slash")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color(red: 0.91, green: 0.77, blue: 0.42))
                .frame(width: 58, height: 58).background(.white.opacity(0.14), in: Circle())
            Text(net.isOnline ? "أنت متصل بالإنترنت" : "أنت بدون إنترنت الآن").font(.ui(.title3, .bold)).foregroundStyle(.white)
            Text(net.isOnline ? "جهّز التطبيق الآن ليعمل كاملا عند انقطاع الاتصال." : "القرآن والأذكار والمواقيت والقبلة والأدوات اليومية تعمل كما هي.")
                .font(.ui(.subheadline)).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(LinearGradient(colors: [Color(red: 0.07, green: 0.30, blue: 0.21), Color(red: 0.04, green: 0.18, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 10, content: c)
            .padding(16).frame(maxWidth: .infinity)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle").font(.system(size: 16, weight: .semibold)).foregroundStyle(Brand.primaryInk)
                .frame(width: 34, height: 34).background(Brand.primaryInk.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.ink)
                Text(value).font(.ui(.footnote)).foregroundStyle(Brand.muted)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func setting(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.ui(.subheadline)).foregroundStyle(Brand.ink)
            Text(sub).font(.ui(.footnote)).foregroundStyle(Brand.muted)
        }
        .multilineTextAlignment(.leading)
    }

    private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
}
