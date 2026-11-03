import SwiftUI
import UIKit
import AyatDesign
import AyatContent

/// Saved ayat ("s:a" keys, newest first), shared by the reader and Library.
enum Favorites {
    static let key = "favorites.ayat"

    static func list(_ raw: String) -> [RecitationPlayer.Position] {
        raw.split(separator: ",").compactMap { part in
            let p = part.split(separator: ":").compactMap { Int($0) }
            return p.count == 2 ? .init(surah: p[0], ayah: p[1]) : nil
        }
    }

    static func toggled(_ raw: String, _ p: RecitationPlayer.Position) -> String {
        var l = list(raw)
        if let i = l.firstIndex(of: p) { l.remove(at: i) } else { l.insert(p, at: 0) }
        return l.map { "\($0.surah):\($0.ayah)" }.joined(separator: ",")
    }
}

enum QuranText {
    /// "مكية · ٧ آيات"
    static func surahLine(_ s: Surah) -> String {
        let place = s.revelation == "Medinan" ? "مدنية" : "مكية"
        return "\(place) · \(ayatCount(s.ayahCount))"
    }

    static func ayatCount(_ n: Int) -> String {
        switch n {
        case 1: "آية واحدة"
        case 2: "آيتان"
        case 3...10: "\(Num.int(n)) آيات"
        default: "\(Num.int(n)) آية"
        }
    }

    /// "[البقرة: ٢٥٥]"
    static func reference(_ p: RecitationPlayer.Position) -> String {
        let name = ContentLibrary.shared.surah(p.surah)?.shortName ?? Num.int(p.surah)
        return "[\(name): \(Num.int(p.ayah))]"
    }

    /// Ayah end mark (U+06DD) with the number, drawn as an ornament by the mushaf font.
    static func marker(_ n: Int) -> String { "\u{06DD}\(Num.int(n))" }
}
