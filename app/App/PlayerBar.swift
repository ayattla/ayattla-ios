import SwiftUI
import UIKit
import AyatDesign
import AyatContent

struct PlayerBar: View {
    @Bindable var player: RecitationPlayer
    let reciterName: String
    let start: () -> RecitationPlayer.Position

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(reciterName).lineLimit(1)
                Spacer()
                if player.failed {
                    Text("تعذر التشغيل، تحقق من الاتصال").foregroundStyle(.red)
                } else if let c = player.current {
                    Text(QuranText.reference(c))
                }
            }
            .font(.ui(.caption)).foregroundStyle(Brand.muted)
            HStack {
                Menu {
                    Picker("تكرار كل آية", selection: $player.repeatEach) {
                        ForEach(RecitationPlayer.repeats, id: \.self) { Text(RecitationPlayer.repeatTitle($0)).tag($0) }
                    }
                } label: {
                    Image(systemName: player.repeatEach == 0 ? "infinity" : player.repeatEach > 1 ? "repeat.1" : "repeat")
                        .frame(width: Brand.minTap, height: Brand.minTap)
                }
                .accessibilityLabel("تكرار كل آية")
                Spacer()
                Button { player.previous() } label: { Image(systemName: "forward.end.fill").frame(width: Brand.minTap, height: Brand.minTap) }
                    .accessibilityLabel("الآية السابقة")
                Button { player.toggle(startAt: start()) } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.ui(.title3)).foregroundStyle(.white)
                        .frame(width: 52, height: 52).background(Brand.primary, in: Circle())
                }
                .accessibilityLabel(player.isPlaying ? "إيقاف مؤقت" : "تشغيل")
                Button { player.next() } label: { Image(systemName: "backward.end.fill").frame(width: Brand.minTap, height: Brand.minTap) }
                    .accessibilityLabel("الآية التالية")
                Spacer()
                Button {
                    let i = RecitationPlayer.speeds.firstIndex(of: player.speed) ?? 1
                    player.speed = RecitationPlayer.speeds[(i + 1) % RecitationPlayer.speeds.count]
                } label: {
                    Text("\(Num.decimal(Double(player.speed), digits: player.speed == 1.25 || player.speed == 0.75 ? 2 : 1))×")
                        .font(.ui(.caption, .medium)).padding(.horizontal, 10).frame(minHeight: 36)
                        .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
                }
                .accessibilityLabel("السرعة")
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .card()
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}
