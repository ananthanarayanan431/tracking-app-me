import Testing
@testable import Spent

struct PhoneImportTests {
    @Test func pairsOpenAndCloseEvents() {
        let text = """
        2026-03-02T09:00:00Z|Instagram|open
        2026-03-02T09:10:00Z|Instagram|close
        2026-03-02T10:00:00Z|WhatsApp
        2026-03-02T10:05:00Z|YouTube
        2026-03-02T10:20:00Z|YouTube
        garbage line
        """
        let r = PhoneImport.parse(text, now: 1_900_000_000)
        let segs = r.byDay.values.flatMap { $0 }.sorted { $0.s < $1.s }
        #expect(r.events == 5)
        #expect(segs.count == 3)
        #expect(segs[0].app == "Instagram" && segs[0].duration == 600)
        #expect(segs[1].app == "WhatsApp" && segs[1].duration == 300)
        #expect(segs[2].app == "YouTube" && segs[2].duration == 900)
        #expect(segs.allSatisfy { $0.dev == .phone })
    }
}
