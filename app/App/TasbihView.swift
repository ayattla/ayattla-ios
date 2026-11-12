import SwiftUI
import UIKit
import AyatDesign

/// Tasbih counter, per design/Tasbih.dc.html and the site's /tools/tasbih (target, counter,
/// reset, saved on the device, vibration). Phrases come from the content pack; the user can add
/// their own.
struct TasbihView: View {
    /// As on the site: الهدف ٣٣ / ١٠٠ / ١٠٠٠ / بدون هدف (0).
    static let targets = [33, 100, 1000, 0]
    static func targetTitle(_ t: Int) -> String { t == 0 ? "بدون هدف" : "الهدف \(Num.int(t))" }
    /// "بقي ٣٣" while under the target; nothing once it is reached or with no target.
    static func remainingText(count: Int, target: Int) -> String? {
        target > 0 && count < target ? "بقي \(Num.int(target - count))" : nil
    }

    @AppStorage("tasbih.count") private var count = 0
    @AppStorage("tasbih.target") private var target = 33
    @AppStorage("tasbih.day") private var day = ""
    @AppStorage("tasbih.todayTotal") private var todayTotal = 0
    @AppStorage("tasbih.phrase") private var phrase = ""
    @AppStorage("tasbih.userPhrases") private var userPhrasesRaw = ""
    @AppStorage("tasbih.haptics") private var haptics = true
    @State private var adding = false
    @State private var newPhrase = ""
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ToolPageHead(id: "tasbih")
                phraseChips
                if !phrase.isEmpty {
                    Text(phrase)
                        .font(.custom("Amiri", size: 26, relativeTo: .title))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 60)
                }
                Button(action: tap) {
                    VStack(spacing: 6) {
                        Text(Num.int(count)).font(.ui(size: 64, .semibold)).monospacedDigit()
                            .contentTransition(.numericText())
                        if let r = Self.remainingText(count: count, target: target) {
                            Text(r).font(.ui(.subheadline)).opacity(0.9)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 250, height: 250)
                    .background(Brand.gradient,
                                in: Circle())
                    .overlay(Circle().stroke(Brand.tint, lineWidth: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("تسبيحة، العدد \(Num.int(count))\(Self.remainingText(count: count, target: target).map { "، \($0)" } ?? "")")

                Text("مجموع تسبيحك المحفوظ: \(Num.int(count))")
                    .font(.ui(.footnote)).foregroundStyle(Brand.muted)

                HStack(spacing: 10) {
                    Menu {
                        Picker("الهدف", selection: $target) {
                            ForEach(Self.targets, id: \.self) { Text(Self.targetTitle($0)).tag($0) }
                        }
                    } label: {
                        Text(Self.targetTitle(target)).padding(.horizontal, 16).frame(minHeight: Brand.minTap)
                            .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                    }
                    Toggle(isOn: $haptics) { Text("اهتزاز عند الإكمال") }
                        .toggleStyle(.button)
                        .buttonBorderShape(.capsule)
                        .frame(minHeight: Brand.minTap)
                }
                .font(.ui(.footnote, .medium))
                .tint(Brand.primary)
            }
            .padding(.vertical, 16)
        }
        .background(Brand.background)
        .brandScreen()
        .navigationTitle("المسبحة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { confirmReset = true } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel("تصفير")
            }
        }
        .confirmationDialog("تصفير العداد؟", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("تصفير", role: .destructive) { count = 0 }
        }
        .alert("عبارة جديدة", isPresented: $adding) {
            TextField("العبارة", text: $newPhrase)
            Button("إضافة") { addPhrase() }
            Button("إلغاء", role: .cancel) { newPhrase = "" }
        }
        .onAppear {
            rollDay()
            if !Self.targets.contains(target) { target = 33 }   // 99 was offered before; the site has no 99
            if phrase.isEmpty, let first = sourcePhrases.first { phrase = first }
        }
    }

    private var sourcePhrases: [String] { ContentLibrary.shared.tasbihPhrases }
    private var userPhrases: [String] { userPhrasesRaw.split(separator: "\n").map(String.init) }

    private var phraseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sourcePhrases + userPhrases, id: \.self) { p in
                    let on = p == phrase
                    Button { phrase = on ? "" : p; count = 0 } label: {
                        Text(Self.plain(p)).lineLimit(1)
                            .font(.ui(.footnote, .medium))
                            .foregroundStyle(on ? .white : .primary)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(on ? Brand.primary : Color.cardSurface, in: Capsule())
                            .overlay(Capsule().stroke(on ? .clear : Brand.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .contextMenu {
                        if userPhrases.contains(p) {
                            Button("حذف العبارة", role: .destructive) { removePhrase(p) }
                        }
                    }
                }
                Button { adding = true } label: {
                    Label("إضافة", systemImage: "plus").font(.ui(.footnote, .medium))
                        .foregroundStyle(Brand.primaryInk)
                        .padding(.horizontal, 14).frame(minHeight: 36)
                        .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(Brand.line))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    /// Chip label without tashkeel, as the site shows it; the full text appears above the counter.
    static func plain(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            switch u.value {
            case 0x064B...0x0670: continue
            case 0x0671: out.unicodeScalars.append("\u{0627}")
            default: out.unicodeScalars.append(u)
            }
        }
        return out
    }

    private func rollDay() {
        let t = AzkarProgress.today()
        if day != t { day = t; todayTotal = 0 }
    }

    private func tap() {
        rollDay()
        withAnimation(.snappy) { count += 1 }
        todayTotal += 1
        // Like the site: the count keeps going past the target; reaching it vibrates once.
        if target > 0 && count == target {
            if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        } else if haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func addPhrase() {
        let p = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        newPhrase = ""
        guard !p.isEmpty, !(sourcePhrases + userPhrases).contains(p) else { return }
        userPhrasesRaw = (userPhrases + [p]).joined(separator: "\n")
        phrase = p
    }

    private func removePhrase(_ p: String) {
        userPhrasesRaw = userPhrases.filter { $0 != p }.joined(separator: "\n")
        if phrase == p { phrase = "" }
    }
}
