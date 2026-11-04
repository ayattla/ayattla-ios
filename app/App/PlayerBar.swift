import SwiftUI
import AyatDesign

// MARK: - Recitation player bar (mushaf and listening)

/// The player under the mushaf and the listening screen: what is playing, a progress bar for the
/// current ayah that can be dragged, and the controls the site's listen tool has: repeat each ayah
/// (1/3/5/10/∞), previous, play, next and speed. The same parts are used in the full player sheet.
struct PlayerBar: View {
    @Bindable var player: RecitationPlayer
    let reciterName: String
    let start: () -> RecitationPlayer.Position

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: player.isPlaying ? "waveform" : "headphones")
                    .font(.ui(.subheadline, .semibold)).foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                    .frame(width: 36, height: 36)
                    .background(Brand.siteGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.current.map(QuranText.reference) ?? "اضغط تشغيل للاستماع من هذه الصفحة")
                        .font(.ui(.footnote, .semibold)).foregroundStyle(Brand.ink).lineLimit(1)
                    Text(reciterName).font(.ui(.caption)).foregroundStyle(Brand.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                if player.failed {
                    Label("تعذر التشغيل", systemImage: "wifi.exclamationmark")
                        .font(.ui(.caption, .semibold)).foregroundStyle(Color(hex: 0xB42318))
                } else if player.current != nil && player.repeatEach != 1 {
                    Text(player.repeatEach == 0 ? "تكرار \(Num.int(player.playCount))"
                                                : "\(Num.int(min(player.playCount, player.repeatEach))) من \(Num.int(player.repeatEach))")
                        .font(.ui(.caption2, .semibold)).foregroundStyle(Brand.primaryInk)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Brand.tint, in: Capsule())
                        .accessibilityLabel("مرات التكرار")
                }
            }
            AyahProgress(player: player)
            HStack(spacing: 4) {
                RepeatMenu(player: player)
                Spacer(minLength: 0)
                PlayerTransport(player: player, size: 54, start: start)
                Spacer(minLength: 0)
                SpeedMenu(player: player)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x0F1F17).opacity(0.10), radius: 16, y: 6)
        .padding(.horizontal, 12).padding(.bottom, 8)
        .frame(maxWidth: 720)
    }
}

/// Previous · play/pause · next. Previous is on the right in RTL (the ayah before).
struct PlayerTransport: View {
    @Bindable var player: RecitationPlayer
    var size: CGFloat = 54
    let start: () -> RecitationPlayer.Position

    var body: some View {
        HStack(spacing: size > 60 ? 26 : 14) {
            Button { player.previous() } label: {
                Image(systemName: "forward.end.fill").font(.ui(size > 60 ? .title2 : .body))
                    .frame(width: Brand.minTap, height: Brand.minTap)
            }
            .accessibilityLabel("الآية السابقة")
            .disabled(player.current == nil)
            Button { player.toggle(startAt: start()) } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.ui(size > 60 ? .title : .title3)).foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Brand.siteGradient, in: Circle())
                    .shadow(color: Color(hex: 0x1F8A62).opacity(0.35), radius: 10, y: 6)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(player.isPlaying ? "إيقاف مؤقت" : "تشغيل")
            Button { player.next() } label: {
                Image(systemName: "backward.end.fill").font(.ui(size > 60 ? .title2 : .body))
                    .frame(width: Brand.minTap, height: Brand.minTap)
            }
            .accessibilityLabel("الآية التالية")
            .disabled(player.current == nil)
        }
        .foregroundStyle(Brand.primaryInk)
    }
}

/// Progress within the current ayah, draggable; elapsed and length either side.
struct AyahProgress: View {
    @Bindable var player: RecitationPlayer
    @State private var dragging: Double?

    var body: some View {
        let fraction = player.duration > 0 ? min(player.elapsed / player.duration, 1) : 0
        VStack(spacing: 2) {
            Slider(value: Binding(get: { dragging ?? fraction }, set: { dragging = $0 }), in: 0...1) { editing in
                if !editing, let d = dragging { player.seek(fraction: d); dragging = nil }
            }
            .tint(Brand.green)
            .disabled(player.duration <= 0)
            .accessibilityLabel("موضع التلاوة في الآية")
            .accessibilityValue("\(Self.clock(player.elapsed)) من \(Self.clock(player.duration))")
            HStack {
                Text(Self.clock((dragging ?? fraction) * player.duration))
                Spacer()
                Text(Self.clock(player.duration))
            }
            .font(.ui(.caption2).monospacedDigit()).foregroundStyle(Brand.muted)
            .accessibilityHidden(true)
        }
    }

    static func clock(_ s: Double) -> String {
        let t = max(0, Int(s.isFinite ? s.rounded() : 0))
        return "\(Num.int(t / 60)):\(t % 60 < 10 ? Num.int(0) : "")\(Num.int(t % 60))"
    }
}

/// Repeat each ayah: 1, 3, 5, 10 times or until moved on (the site's options).
struct RepeatMenu: View {
    @Bindable var player: RecitationPlayer

    var body: some View {
        Menu {
            Picker("تكرار كل آية", selection: $player.repeatEach) {
                ForEach(RecitationPlayer.repeats, id: \.self) { Text(RecitationPlayer.repeatTitle($0)).tag($0) }
            }
        } label: {
            ControlChip(symbol: player.repeatEach == 1 ? "repeat" : player.repeatEach == 0 ? "infinity" : "repeat.1",
                        text: player.repeatEach == 0 ? "∞" : "\(Num.int(player.repeatEach))×",
                        on: player.repeatEach != 1)
        }
        .accessibilityLabel("تكرار كل آية: \(RecitationPlayer.repeatTitle(player.repeatEach))")
    }
}

/// Playback speed: 0.75, 1, 1.25, 1.5 (the site's options).
struct SpeedMenu: View {
    @Bindable var player: RecitationPlayer

    var body: some View {
        Menu {
            Picker("السرعة", selection: $player.speed) {
                ForEach(RecitationPlayer.speeds, id: \.self) { Text(Self.title($0)).tag($0) }
            }
        } label: {
            ControlChip(symbol: "gauge.with.dots.needle.50percent", text: Self.title(player.speed), on: player.speed != 1)
        }
        .accessibilityLabel("السرعة \(Self.title(player.speed))")
    }

    static func title(_ s: Float) -> String {
        "\(Num.decimal(Double(s), digits: s == 1.25 || s == 0.75 ? 2 : 1))×"
    }
}

/// Small rounded control: icon and value; green when it is set to something other than the default.
struct ControlChip: View {
    let symbol: String
    let text: String
    var on = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.ui(.caption, .semibold))
            Text(text).font(.ui(.caption, .semibold)).monospacedDigit()
        }
        .foregroundStyle(on ? Color.white : Brand.ink)
        .padding(.horizontal, 10).frame(minWidth: 58, minHeight: Brand.minTap)
        .background {
            if on { Capsule().fill(Brand.siteGradient) } else { Capsule().fill(Brand.surface2) }
        }
        .overlay(Capsule().strokeBorder(on ? Color.clear : Brand.line, lineWidth: 1))
        .contentShape(Capsule())
    }
}
