import SwiftUI
import UIKit
import AyatDesign
import AyatContent

struct AyahActions: View {
    let position: RecitationPlayer.Position
    let isFavorite: Bool
    let canListen: Bool
    let onListen: () -> Void
    let onFavorite: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let text = (try? ContentLibrary.shared.store?.ayat(surah: position.surah, from: position.ayah, to: position.ayah))?.first?.textUthmani ?? ""
        let share = "﴿\(text)﴾ \(QuranText.reference(position))"
        NavigationStack {
            List {
Group {
                Section {
                    Text(text).font(.custom(ContentLibrary.mushafFont, size: 21, relativeTo: .body))
                        .lineSpacing(8).padding(.vertical, 6)
                }
                Section {
                    if canListen {
                        Button { onListen() } label: { Label("استمع من هنا", systemImage: "play.fill") }
                    }
                    Button {
                        onFavorite(); dismiss()
                    } label: {
                        Label(isFavorite ? "أزل من المفضلة" : "أضف للمفضلة", systemImage: isFavorite ? "heart.slash" : "heart")
                    }
                    Button {
                        UIPasteboard.general.string = share; dismiss()
                    } label: { Label("نسخ الآية", systemImage: "doc.on.doc") }
                    ShareLink(item: share) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                    NavigationLink { AyahCardView(surah: position.surah, from: position.ayah) } label: {
                        Label("اصنع بطاقة", systemImage: "rectangle.portrait")
                    }
                }
            
}.listRowBackground(Brand.surface)
}
            .brandScreen()
            .navigationTitle(QuranText.reference(position))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
        }
    }
}
