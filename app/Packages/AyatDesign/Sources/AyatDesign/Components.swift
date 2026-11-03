import SwiftUI

// Shared building blocks (master prompt §3, "مكونات الواجهة الموحدة"). Every one reads the
// tokens in Brand.swift, so a change to the site's palette or radii lands everywhere at once.
// Names follow the master prompt: SectionHeader, PrimaryButton, SecondaryButton, ToolCard,
// CategorySelector, EmptyState, LoadingState, ErrorState. AppCard is the `card()` modifier.

/// Section title with an optional sub-line and a trailing action, as the site's `h2 + p` heads.
public struct SectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.subtitle = subtitle; self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.ui(.title3, .semibold)).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(.ui(.footnote)).foregroundStyle(Brand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

public extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) { self.init(title, subtitle: subtitle) { EmptyView() } }
}

/// The site's main button: emerald pill with ivory text (`.btn-primary`).
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(.subheadline, .semibold))
            .foregroundStyle(Brand.onPrimary)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .background(Brand.primary, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The site's outline button (`.btn-ghost`): line border, emerald ink.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(.subheadline, .medium))
            .foregroundStyle(Brand.primaryInk)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Brand.surface, in: Capsule())
            .overlay(Capsule().stroke(Brand.lineStrong, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Gold pill on emerald panels (hero buttons).
public struct GoldButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(.subheadline, .semibold))
            .foregroundStyle(Brand.primary)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Brand.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle { static var brandPrimary: PrimaryButtonStyle { .init() } }
public extension ButtonStyle where Self == SecondaryButtonStyle { static var brandSecondary: SecondaryButtonStyle { .init() } }
public extension ButtonStyle where Self == GoldButtonStyle { static var brandGold: GoldButtonStyle { .init() } }

/// Tool card as on the site's tool directory: icon tile in gold-soft, title, one-line description.
public struct ToolCard: View {
    let title: String
    let subtitle: String?
    let symbol: String

    public init(_ title: String, subtitle: String? = nil, symbol: String) {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol
    }

    /// Drawn by the v2 service card, so every list of services looks the same.
    public var body: some View {
        ServiceCard(title, subtitle: subtitle, symbol: symbol)
    }
}

/// Chip row for picking one category (site: `.chip` / `.chip.on`).
public struct CategorySelector<ID: Hashable>: View {
    let items: [(id: ID, title: String)]
    @Binding var selection: ID

    public init(_ items: [(id: ID, title: String)], selection: Binding<ID>) {
        self.items = items; self._selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    let on = item.id == selection
                    Button { selection = item.id } label: {
                        Text(item.title).font(.ui(.footnote, .medium)).lineLimit(1)
                            .foregroundStyle(on ? Brand.onPrimary : Brand.ink)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(on ? Brand.primary : Brand.surface, in: Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : Brand.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// Empty, loading and error states with the brand's colors and the site's wording style.
public struct EmptyState: View {
    let title: String, symbol: String, message: String?
    public init(_ title: String, symbol: String, message: String? = nil) { self.title = title; self.symbol = symbol; self.message = message }
    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol).font(.ui(.headline)).foregroundStyle(Brand.ink)
        } description: {
            if let message { Text(message).font(.ui(.footnote)).foregroundStyle(Brand.muted) }
        }
    }
}

public struct LoadingState: View {
    let title: String
    public init(_ title: String = "جار التحميل") { self.title = title }
    public var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(Brand.primaryInk)
            Text(title).font(.ui(.footnote)).foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

public struct ErrorState: View {
    let title: String, message: String
    let retry: (() -> Void)?
    public init(_ title: String = "تعذر التحميل", message: String = "تحقق من الاتصال ثم حاول مرة أخرى", retry: (() -> Void)? = nil) {
        self.title = title; self.message = message; self.retry = retry
    }
    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "wifi.exclamationmark").font(.ui(.headline)).foregroundStyle(Brand.ink)
        } description: {
            Text(message).font(.ui(.footnote)).foregroundStyle(Brand.muted)
        } actions: {
            if let retry { Button("حاول مرة أخرى", action: retry).buttonStyle(.brandSecondary) }
        }
    }
}
