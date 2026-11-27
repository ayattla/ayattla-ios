import SwiftUI
import AyatDesign
import AyatContent

/// «مسار الآية»: one ayah, five steps in order — listen, understand, memorise, recite, share.
/// Same steps, wording and keys as the Android screen.
enum PathStep: String, CaseIterable, Identifiable {
    case listen, meaning, memorize, recite, share
    var id: String { rawValue }
    var title: String {
        switch self {
        case .listen: "استمع"
        case .meaning: "افهم المعنى"
        case .memorize: "احفظ"
        case .recite: "التسميع"
        case .share: "شارك"
        }
    }
    var line: String {
        switch self {
        case .listen: "استمع للآية بصوت قارئك"
        case .meaning: "التفسير الميسر لهذه الآية"
        case .memorize: "كرر الآية خمس مرات حتى تثبت"
        case .recite: "اقرأها من حفظك ويصحح لك التطبيق"
        case .share: "اصنع بطاقة بالآية ومصدرها"
        }
    }
    static func key(_ s: Int, _ a: Int, _ step: PathStep) -> String { "path.\(s):\(a).\(step.rawValue)" }
    static func done(_ s: Int, _ a: Int, _ step: PathStep) -> Bool { UserDefaults.standard.bool(forKey: key(s, a, step)) }
}

struct AyahPathView: View {
    let surah: Int
    @State var ayah: Int
    @AppStorage(Prefs.reciter) private var reciter = Prefs.defaultReciter
    @State private var player = (AudioCenter.shared.active as? RecitationPlayer) ?? RecitationPlayer()
    @State private var tick = 0
    @State private var showMeaning = false
    @State private var tafsir: String?
    @State private var meaningFailed = false
    private let lib = ContentLibrary.shared

    var body: some View {
        let text = (try? lib.store?.ayat(surah: surah, from: ayah, to: ayah))?.first?.textUthmani ?? ""
        let count = lib.surah(surah)?.ayahCount ?? ayah
        let doneCount = PathStep.allCases.filter { PathStep.done(surah, ayah, $0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(text).font(.custom(ContentLibrary.mushafFont, size: 22, relativeTo: .title3)).lineSpacing(12)
                    .foregroundStyle(Brand.ink)
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .surface(.raised, radius: 18)
                Text("أتممت \(Num.int(doneCount)) من \(Num.int(PathStep.allCases.count)) خطوات")
                    .font(.ui(.subheadline, .semibold)).foregroundStyle(Brand.primaryInk)
                ForEach(Array(PathStep.allCases.enumerated()), id: \.element) { i, step in
                    stepCard(i, step)
                }
                if ayah < count {
                    Button("الآية التالية") {
                        ayah += 1; showMeaning = false; tafsir = nil; meaningFailed = false
                    }
                    .buttonStyle(.brandSecondary).frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .id(tick)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("مسار الآية")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(showMeaning)-\(ayah)") {
            guard showMeaning, tafsir == nil else { return }
            meaningFailed = false
            if let c = try? await QF.words(chapter: surah, lang: "en"),
               let t = c.verses.first(where: { $0.n == ayah || $0.key == "\(surah):\(ayah)" })?.tafsir {
                tafsir = t
            } else { meaningFailed = true }
        }
    }

    @ViewBuilder private func stepCard(_ i: Int, _ step: PathStep) -> some View {
        let done = PathStep.done(surah, ayah, step)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? Brand.green : Brand.tint)
                    if done { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) }
                    else { Text(Num.int(i + 1)).font(.ui(.subheadline, .bold)).foregroundStyle(Brand.primaryInk) }
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title).font(.ui(.headline)).foregroundStyle(Brand.ink)
                    Text(step.line).font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                }
            }
            if step == .meaning && showMeaning {
                Group {
                    if let t = tafsir {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t).font(.ui(.body)).foregroundStyle(Brand.ink)
                            Text("التفسير الميسر · مجمع الملك فهد").font(.ui(.caption, .semibold)).foregroundStyle(Brand.goldInk)
                        }
                    } else if meaningFailed {
                        Text("تعذر جلب التفسير، ويحتاج اتصالا بالإنترنت أول مرة").font(.ui(.subheadline)).foregroundStyle(Brand.muted)
                    } else {
                        ProgressView()
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            switch step {
            case .recite:
                NavigationLink { TasmeeView(surah: surah, from: ayah, to: ayah).onAppear { mark(step) } } label: {
                    Text("ابدأ التسميع").frame(maxWidth: .infinity)
                }
                .brandStyle(primary: !done)
            case .share:
                NavigationLink { AyahCardView(surah: surah, from: ayah).onAppear { mark(step) } } label: {
                    Text("اصنع بطاقة").frame(maxWidth: .infinity)
                }
                .brandStyle(primary: !done)
            default:
                Button {
                    switch step {
                    case .listen: play(repeat: 1); mark(step)
                    case .memorize: play(repeat: 5); mark(step)
                    case .meaning: if showMeaning { mark(step) } else { showMeaning = true }
                    default: break
                    }
                } label: {
                    Text(step == .listen ? "استمع" : step == .memorize ? "كرر خمس مرات" : (showMeaning ? "فهمت" : "اعرض المعنى"))
                        .frame(maxWidth: .infinity)
                }
                .brandStyle(primary: !done)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(.raised, radius: 16)
    }

    private func play(repeat n: Int) {
        player.folder = lib.reciterFolders[reciter]
        player.ayahCount = { lib.surah($0)?.ayahCount ?? 0 }
        player.repeatEach = n
        let p = RecitationPlayer.Position(surah: surah, ayah: ayah)
        player.stopAt = p
        player.play(from: p)
    }

    private func mark(_ step: PathStep) {
        UserDefaults.standard.set(true, forKey: PathStep.key(surah, ayah, step))
        Stats.event("path_step", step.rawValue)
        tick += 1
    }
}

private extension View {
    @ViewBuilder func brandStyle(primary: Bool) -> some View {
        if primary { buttonStyle(.brandPrimary) } else { buttonStyle(.brandSecondary) }
    }
}
