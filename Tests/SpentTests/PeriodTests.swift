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

struct EditWindowTests {
    @Test func todayAndPreviousTwoDaysAreEditable() {
        let t = "2026-03-01"
        #expect(Fmt.isEditable("2026-03-01", today: t))
        #expect(Fmt.isEditable("2026-02-28", today: t))
        #expect(Fmt.isEditable("2026-02-27", today: t))
    }

    @Test func olderAndFutureDaysAreLocked() {
        let t = "2026-03-01"
        #expect(!Fmt.isEditable("2026-02-26", today: t))
        #expect(!Fmt.isEditable("2025-12-31", today: t))
        #expect(!Fmt.isEditable("2026-03-02", today: t))
    }
}
