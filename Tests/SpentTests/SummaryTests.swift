import Testing
@testable import Spent

struct SummaryTests {
    @Test func testDurationFormatting() {
        #expect(Fmt.duration(42) == "42s")
        #expect(Fmt.duration(45 * 60) == "45m")
        #expect(Fmt.duration(3600) == "1h")
        #expect(Fmt.duration(3600 + 23 * 60) == "1h 23m")
        #expect(Fmt.mmss(1500) == "25:00")
    }

    @Test func testClassifierDefaultsAndOverrides() {
        let c = Classifier()
        #expect(c.classify(app: "Google Chrome", dom: "youtube.com").cat == "Entertainment")
        #expect(c.classify(app: "Cursor").kind == .p)
        #expect(c.classify(app: "Safari").cat == "Browsing")
        #expect(c.classify(app: "X").cat == "Social")
        c.overrides = ["site:youtube.com": Override(cat: "Development", type: .p)]
        #expect(c.classify(app: "Google Chrome", dom: "youtube.com").kind == .p)
    }

    @Test func testSummarizeCountsSessionsAndSwitches() {
        let base = Fmt.date("2026-01-05").timeIntervalSince1970 + 9 * 3600
        let segs = [
            Segment(s: base, e: base + 600, app: "Cursor"),
            Segment(s: base + 600, e: base + 1200, app: "Cursor"),
            Segment(s: base + 1200, e: base + 1500, app: "Google Chrome", dom: "youtube.com", title: "Video"),
        ]
        let S = Summarizer.summarize(segs, classifier: Classifier())
        #expect(S.t == 1500)
        #expect(S.n == 2)
        #expect(S.sw == 1)
        #expect(S.L == 1200)
        #expect(S.La == "Cursor")
        #expect(S.h[9] == 1500)
        #expect(S.productive == 1200)
        #expect(S.distracting == 300)
        #expect(Summarizer.sessions(segs).count == 2)
        let M = Summarizer.merge([S, S])
        #expect(M.t == 3000)
        #expect(M.a["Cursor"] == 2400)
    }
}
