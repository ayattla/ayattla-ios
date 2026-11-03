import UIKit
import SwiftUI
import AyatDesign

/// UIKit chrome in the site's identity: IBM Plex Sans Arabic titles in ink, ivory bars, gold-ink
/// selected tab, segmented controls in Plex.
enum BrandAppearance {
    static func font(_ weight: String, _ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: "IBMPlexSansArabic-\(weight)", size: size) ?? .systemFont(ofSize: size)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    static func apply() {
        // UIKit right to left, matching the SwiftUI environment set at the root (see AyatTutlaApp).
        UIView.appearance().semanticContentAttribute = .forceRightToLeft

        let ink = UIColor(Brand.ink)
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.backgroundColor = UIColor(Brand.background)
        bar.titleTextAttributes = [.font: font("SemiBold", 17, .headline), .foregroundColor: ink]
        bar.largeTitleTextAttributes = [.font: font("Bold", 32, .largeTitle), .foregroundColor: ink]
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.titleTextAttributes = bar.titleTextAttributes
        scrolled.largeTitleTextAttributes = bar.largeTitleTextAttributes
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: font("Medium", 17, .body)], for: .normal)

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        let item = UITabBarItemAppearance()
        item.normal.titleTextAttributes = [.font: font("Medium", 11, .caption2), .foregroundColor: UIColor(Brand.muted)]
        item.normal.iconColor = UIColor(Brand.muted)
        item.selected.titleTextAttributes = [.font: font("SemiBold", 11, .caption2), .foregroundColor: UIColor(Brand.primaryInk)]
        item.selected.iconColor = UIColor(Brand.primaryInk)
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        UISegmentedControl.appearance().setTitleTextAttributes([.font: font("Medium", 13, .footnote)], for: .normal)
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Brand.surface)
    }
}
