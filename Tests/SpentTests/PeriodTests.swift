import Testing
import Foundation
@testable import Spent

struct PeriodTests {
    @Test func weekStartsOnMonday() {
        let r = DayRange.period(.week, anchor: Fmt.date("2026-01-07")) // a Wednesday
        #expect(r.all.first == "2026-01-05")
        #expect(r.all.count == 7)
    }

    @Test func monthAndYearSpans() {
        #expect(DayRange.period(.month, anchor: Fmt.date("2024-02-10")).all.count == 29)
        #expect(DayRange.period(.year, anchor: Fmt.date("2025-06-01")).all.count == 365)
    }

    @Test func lastNEndsToday() {
        let r = DayRange.lastN(7)
        #expect(r.keys.count == 7)
        #expect(r.keys.last == Fmt.todayKey)
    }
}
