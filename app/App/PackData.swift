import SwiftUI
import AVFoundation
import AyatDesign
import AyatContent

// MARK: - Pack data (prayer guide, duas)

struct PrayerGuide: Codable {
    struct Item: Codable, Hashable { let text: String; let source: String; let grade: String; let url: String }
    struct Section: Codable, Hashable { let title: String; let items: [Item] }
    let lead: String
    let source: String
    let source_url: String
    let sections: [Section]
}

struct DuasData: Codable {
    struct QuranRef: Codable, Hashable { let s: Int; let a: Int; let b: Int }
    struct Item: Codable, Hashable { let i: Int?; let text: String }
    struct Chapter: Codable, Hashable { let name: String; let items: [Item] }
    struct Need: Codable, Hashable { let need: String; let chapters: [Chapter] }
    let quran: [QuranRef]
    let needs: [Need]
}

extension ContentLibrary {
    func json<T: Decodable>(_ key: String) -> T? {
        guard let raw = (try? store?.meta(key)) ?? nil, !raw.isEmpty else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(raw.utf8))
    }
    var prayerGuide: PrayerGuide? { json("prayer_guide") }
    var duas: DuasData? { json("duas") }
}
