import SwiftUI
import UIKit
import AyatDesign
import AyatContent

/// The thirty ajza', each opening the mushaf at its first page (pack's juz column).
struct JuzListView: View {
    private let lib = ContentLibrary.shared
    private var starts: [JuzStart] { (try? lib.store?.juzStarts()) ?? [] }

    var body: some View {
        List(starts) { j in
            Group {
                NavigationLink {
                    MushafReader(startPage: j.page, focus: .init(surah: j.surah, ayah: j.ayah))
                } label: {
                    HStack(spacing: 12) {
                        Text(Num.int(j.juz)).font(.ui(.headline)).foregroundStyle(Brand.primary)
                            .frame(width: 40, height: 40).background(Brand.goldSoft, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("الجزء \(Num.int(j.juz))").font(.ui(.headline))
                            Text("\(lib.surah(j.surah)?.shortName ?? "") · الآية \(Num.int(j.ayah)) · صفحة \(Num.int(j.page))")
                                .font(.ui(.caption)).foregroundStyle(Brand.muted)
                        }
                    }
                    .frame(minHeight: Brand.minTap)
                }
            }
            .listRowBackground(Brand.surface)
        }
        .overlay { if starts.isEmpty { EmptyState("الأجزاء غير متاحة", symbol: "list.number") } }
        .brandScreen()
        .navigationTitle("الأجزاء")
        .navigationBarTitleDisplayMode(.inline)
    }
}
