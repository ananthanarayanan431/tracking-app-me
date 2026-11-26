import Testing
@testable import Spent

struct StorageTests {
    @Test func parsesTrackerLinesAndSkipsBadOnes() {
        let text = "100\t160\tGoogle Chrome\tgithub.com\tPR #1\tWork\n200\t150\tBad\n300\t360\tCursor\t\t\t\n\n"
        let segs = Storage.parseTSV(text)
        #expect(segs.count == 2)
        #expect(segs[0].dom == "github.com")
        #expect(segs[0].prof == "Work")
        #expect(segs[1].app == "Cursor")
    }

    @Test func lineRoundTrips() {
        let g = Segment(s: 10, e: 70, app: "Safari", dom: "apple.com", title: "Tab\twith tab", prof: "")
        let back = Storage.parseTSV(Storage.line(g))
        #expect(back.first?.title == "Tab with tab")
        #expect(back.first?.e == 70)
    }
}
