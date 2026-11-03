#if DEBUG
import SwiftUI
import UIKit
import AyatDesign

/// CI diagnostic for Arabic shaping (iOS 17): the same words drawn in each way the app draws text.
struct FontDiagnosticsView: View {
    private let s = "حاسبة الزكاة والأذكار"
    var body: some View {
        List {
            Section("في قائمة") {
                Text("1 system: " + s)
                Text("2 ui(.body): " + s).font(.ui(.body))
                Text("3 custom fixed: " + s).font(.custom("IBMPlexSansArabic-Regular", fixedSize: 17))
                Text("4 custom relative: " + s).font(.custom("IBMPlexSansArabic-Regular", size: 17, relativeTo: .body))
                Text("5 Font(UIFont): " + s).font(Font(UIFont(name: "IBMPlexSansArabic-Regular", size: 17) ?? .systemFont(ofSize: 17)))
                Text("6 semibold: " + s).font(.ui(.body, .semibold))
                Text("7 Amiri: " + s).font(.custom("Amiri", size: 17))
                Text("8 family: " + s).font(.custom("IBM Plex Sans Arabic", size: 17))
                Text("9 found: \(UIFont(name: "IBMPlexSansArabic-Regular", size: 17)?.fontName ?? "nil")")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading) {
                Text("A scroll ui(.body): " + s).font(.ui(.body))
                Text("B scroll lineLimit: " + s).font(.ui(.body)).lineLimit(1)
                Text("C scroll no env font: " + s).font(nil)
            }
            .padding().background(.white)
        }
    }
}
#endif
