import XCTest
import AyatCalc
@testable import AyatTutla

/// Expected values were read from the live site (ayattla.com/tools/zakat and /tools/kids-juz-amma).
final class ToolsParityTests: XCTestCase {
    func testZakatMoneyMatchesSiteFormat() {
        XCTAssertEqual(ZakatSummary.money(2490.625), "٢,٤٩٠.٦٣")
        XCTAssertEqual(ZakatSummary.money(100_000), "١٠٠,٠٠٠")
        XCTAssertEqual(ZakatSummary.money(1257.5), "١,٢٥٧.٥")
        XCTAssertEqual(ZakatSummary.money(-5000), "-٥,٠٠٠")
    }

    func testZakatSummaryAboveNisab() {
        var f = ZakatForm()
        f.goldPrice = "300"; f.cash = "100000"; f.gold21 = "10"; f.debts = "5000"; f.receivables = "2000"
        let s = ZakatSummary(form: f, result: Zakat.calculate(f.input))
        XCTAssertEqual(s.due, "٢,٤٩٠.٦٣ ريال")
        XCTAssertEqual(s.status, "بلغ مالك النصاب")
        XCTAssertEqual(s.lines.map(\.label), ["النقد والأرصدة", "قيمة الذهب", "ديون لك", "يخصم: ديون عليك"])
        XCTAssertEqual(s.lines.map(\.value), ["١٠٠,٠٠٠ ريال", "٢,٦٢٥ ريال", "٢,٠٠٠ ريال", "-٥,٠٠٠ ريال"])
        XCTAssertEqual(s.net, "٩٩,٦٢٥ ريال")
        XCTAssertEqual(s.nisab, "٢٥,٥٠٠ ريال")
    }

    func testZakatSummaryBelowNisabAndWithoutPrice() {
        var f = ZakatForm()
        f.goldPrice = "300"; f.cash = "1000"
        var s = ZakatSummary(form: f, result: Zakat.calculate(f.input))
        XCTAssertEqual(s.due, "٠")
        XCTAssertEqual(s.status, "لم يبلغ النصاب — بقي ٢٤,٥٠٠ ريال")
        f.goldPrice = ""
        s = ZakatSummary(form: f, result: Zakat.calculate(f.input))
        XCTAssertEqual(s.due, "—")
        XCTAssertEqual(s.status, "أدخل سعر غرام الذهب لحساب النصاب")
        XCTAssertEqual(s.nisab, "أدخل السعر")
    }

    func testZakatSilverBasisAndCurrency() {
        var f = ZakatForm()
        f.currency = "دولار"; f.basis = "silver"; f.goldPrice = "300"; f.silverPrice = "3"; f.trade = "50000"; f.silverGrams = "100"
        let s = ZakatSummary(form: f, result: Zakat.calculate(f.input))
        XCTAssertEqual(s.due, "١,٢٥٧.٥ دولار")
        XCTAssertEqual(s.nisab, "١,٧٨٥ دولار")
        XCTAssertEqual(s.lines.map(\.label), ["عروض التجارة", "قيمة الفضة"])
    }

    func testZakatFormAcceptsArabicDigitsAndRoundTrips() {
        XCTAssertEqual(ZakatForm.number("١٢٫٥"), 12.5)
        XCTAssertEqual(ZakatForm.number("1,250"), 1250)
        var f = ZakatForm(); f.cash = "500"; f.currency = "درهم"
        XCTAssertEqual(ZakatForm.decode(f.encoded()), f)
        XCTAssertEqual(ZakatForm.currencies, ["ريال", "درهم", "دينار", "جنيه", "دولار", "ليرة"])
    }

    func testKidsSurahsBadgesAndStars() {
        XCTAssertEqual(KidsProgress.surahs.count, 37)
        XCTAssertEqual(KidsProgress.surahs.first, 114)
        XCTAssertEqual(KidsProgress.surahs.last, 78)
        XCTAssertEqual(KidsProgress.badges.map(\.count), [1, 5, 10, 20, 37])
        XCTAssertEqual(KidsProgress.certificateStars(0), 1)
        XCTAssertEqual(KidsProgress.certificateStars(8), 1)
        XCTAssertEqual(KidsProgress.certificateStars(9), 2)
        XCTAssertEqual(KidsProgress.certificateStars(37), 5)
    }

    func testKidsCertificateSize() {
        let img = KidsCertificate(name: "عبدالله", count: 3).render()
        XCTAssertEqual(img.size, CGSize(width: 1080, height: 1350))
        XCTAssertNotNil(img.pngData())
    }

    func testEverySiteToolIsInTheApp() {
        XCTAssertTrue(ToolItem.allCases.contains(.kids))
        XCTAssertEqual(ToolItem.kids.title, "تحفيظ الأطفال جزء عم")
    }
}
