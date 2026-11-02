import Foundation

/// Zakat calculator, port of ayattla.com/tools/zakat `calc()`:
/// nisab = 85 g gold or 595 g silver; rate 2.5 % of the net when net >= nisab.
public enum Zakat {
    public enum Basis: String, Sendable { case gold, silver }

    public struct Input: Equatable, Sendable {
        public var goldPricePerGram24 = 0.0, silverPricePerGram = 0.0
        public var cash = 0.0, trade = 0.0
        public var gold24 = 0.0, gold21 = 0.0, gold18 = 0.0, silverGrams = 0.0
        public var receivables = 0.0, debts = 0.0
        public var basis: Basis = .gold
        public init() {}
    }

    public struct Result: Equatable, Sendable {
        public let goldValue, silverValue, total, nisab, due: Double
        public var reachedNisab: Bool { nisab > 0 && total >= nisab }
    }

    public static func calculate(_ v: Input) -> Result {
        let gold = (v.gold24 + v.gold21 * 21 / 24 + v.gold18 * 18 / 24) * v.goldPricePerGram24
        let silver = v.silverGrams * v.silverPricePerGram
        let total = v.cash + v.trade + gold + silver + v.receivables - v.debts
        let nisab = v.basis == .silver ? 595 * v.silverPricePerGram : 85 * v.goldPricePerGram24
        let due = (nisab > 0 && total >= nisab) ? total * 0.025 : 0
        return Result(goldValue: gold, silverValue: silver, total: total, nisab: nisab, due: due)
    }
}
