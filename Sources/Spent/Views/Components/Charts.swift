import SwiftUI

/// Lays children side by side with widths proportional to `spans` (a 12-column rhythm),
/// all stretched to the tallest child. Below `stackBelow` points wide it stacks them.
struct SpanRow: Layout {
    var spans: [CGFloat]
    var spacing: CGFloat = 16
    var stackBelow: CGFloat = 900

    private func widths(_ total: CGFloat, count: Int) -> [CGFloat] {
        let sp = spans.count == count ? spans : Array(repeating: 1, count: count)
        let avail = total - spacing * CGFloat(count - 1)
        let sum = sp.reduce(0, +)
        return sp.map { avail * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 1000
        if w < stackBelow {
            let hs = subviews.map { $0.sizeThatFits(ProposedViewSize(width: w, height: nil)).height }
            return CGSize(width: w, height: hs.reduce(0, +) + spacing * CGFloat(max(0, hs.count - 1)))
        }
        let ws = widths(w, count: subviews.count)
        let h = zip(subviews, ws).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if bounds.width < stackBelow {
            var y = bounds.minY
            for s in subviews {
                let h = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
                s.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: h))
                y += h + spacing
            }
            return
        }
        let ws = widths(bounds.width, count: subviews.count)
        var x = bounds.minX
        for (s, w) in zip(subviews, ws) {
            s.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w + spacing
        }
    }
}

/// "Your day on tape": one lane per device plus an Away lane, positioned across 24 hours.
struct DayTape: View {
    @Environment(\.skin) private var skin
    var dayStart: Double
    var sessions: [Session]
    var showMac: Bool
    var showPhone: Bool
    var gaps: [Gap]
    var awayFor: (Double) -> AwayEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showMac { lane("Mac", items: sessions.filter { $0.dev == .mac }) }
            if showPhone { lane("iPhone", items: sessions.filter { $0.dev == .phone }) }
            if !gaps.isEmpty, showMac { awayLane }
            HStack(spacing: 0) {
                Color.clear.frame(width: 52)
                GeometryReader { geo in
                    ForEach([0, 3, 6, 9, 12, 15, 18, 21], id: \.self) { h in
                        Text(Fmt.pad(h)).font(.system(size: 10)).foregroundStyle(skin.dim)
                            .position(x: geo.size.width * CGFloat(h) / 24 + 8, y: 6)
                    }
                }
                .frame(height: 14)
            }
        }
    }

    private func x(_ t: Double, _ w: CGFloat) -> CGFloat { w * CGFloat((t - dayStart) / Fmt.day) }

    private func lane(_ name: String, items: [Session]) -> some View {
        HStack(spacing: 0) {
            Text(name).font(.system(size: 12)).foregroundStyle(skin.muted).frame(width: 52, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(skin.panel2)
                    ForEach(items) { g in
                        Rectangle().fill(Color(hex: Palette.shared.color(g.app)))
                            .frame(width: max(1, x(g.e, geo.size.width) - x(g.s, geo.size.width)))
                            .offset(x: x(g.s, geo.size.width))
                            .help("\(g.app)\(g.prof.isEmpty ? "" : " (\(g.prof))")\(g.dom.isEmpty ? "" : " · \(g.dom)")  \(Fmt.clock(g.s))–\(Fmt.clock(g.e)) (\(Fmt.duration(g.e - g.s)))")
                    }
                    nowMarker(geo.size.width)
                }
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var awayLane: some View {
        HStack(spacing: 0) {
            Text("Away").font(.system(size: 12)).foregroundStyle(skin.muted).frame(width: 52, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(skin.panel2)
                    ForEach(gaps) { g in
                        let a = awayFor(g.s)
                        Rectangle()
                            .fill(a.map { Color(hex: $0.color) } ?? skin.dim.opacity(0.35))
                            .frame(width: max(2, x(g.e, geo.size.width) - x(g.s, geo.size.width)))
                            .offset(x: x(g.s, geo.size.width))
                            .help("\(a?.name ?? "Not logged yet")  \(Fmt.clock(g.s))–\(Fmt.clock(g.e)) (\(Fmt.duration(g.e - g.s)))")
                    }
                }
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    @ViewBuilder private func nowMarker(_ w: CGFloat) -> some View {
        let now = Date().timeIntervalSince1970
        if now > dayStart, now < dayStart + Fmt.day {
            Rectangle().fill(skin.acc).frame(width: 2).offset(x: x(now, w))
        }
    }
}

/// Every day of the year as a GitHub-style grid (weeks as columns, Monday first).
struct YearHeatmap: View {
    @Environment(\.skin) private var skin
    var keys: [String]
    var values: [String: Double]

    var body: some View {
        let lead = (Fmt.weekday(keys.first ?? Fmt.todayKey) + 6) % 7
        let cells: [String?] = Array(repeating: nil, count: lead) + keys.map { Optional($0) }
        let weeks = Int(ceil(Double(cells.count) / 7))
        let mx = max(values.values.max() ?? 1, 1)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { d in
                            let i = w * 7 + d
                            let k = i < cells.count ? cells[i] : nil
                            let v = k.flatMap { values[$0] } ?? 0
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(v > 0 ? skin.acc.opacity(0.15 + 0.85 * sqrt(v / mx)) : skin.panel2)
                                .frame(width: 11, height: 11)
                                .opacity(k == nil ? 0 : 1)
                                .help(k.map { "\(Fmt.shortDate($0)) · \(Fmt.duration(v))" } ?? "")
                        }
                    }
                }
            }
        }
    }
}

/// Average-by-weekday-and-hour heat grid used on Insights.
struct WeekHourHeatmap: View {
    @Environment(\.skin) private var skin
    /// [weekday 0=Sun][hour] average seconds
    var grid: [[Double]]

    var body: some View {
        let order = [1, 2, 3, 4, 5, 6, 0]
        let mx = max(grid.flatMap { $0 }.max() ?? 1, 1)
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Text("").frame(width: 34)
                ForEach(0..<24, id: \.self) { h in
                    Text(h % 3 == 0 ? Fmt.pad(h) : "").font(.system(size: 9)).foregroundStyle(skin.dim).frame(maxWidth: .infinity)
                }
            }
            ForEach(order, id: \.self) { w in
                HStack(spacing: 3) {
                    Text(Fmt.weekdays[w]).font(.system(size: 11)).foregroundStyle(skin.muted).frame(width: 34, alignment: .leading)
                    ForEach(0..<24, id: \.self) { h in
                        let v = grid[w][h]
                        RoundedRectangle(cornerRadius: 3)
                            .fill(v > 0 ? skin.acc.opacity(0.12 + 0.88 * sqrt(v / mx)) : skin.panel2)
                            .frame(maxWidth: .infinity).frame(height: 18)
                            .help("\(Fmt.weekdays[w]) \(Fmt.pad(h)):00 · avg \(Fmt.duration(v))")
                    }
                }
            }
        }
    }
}

/// Legend chips: coloured dot + name.
struct Legend: View {
    @Environment(\.skin) private var skin
    var items: [(String, Color)]

    var body: some View {
        FlowRow(spacing: 12) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 5) {
                    Circle().fill(items[i].1).frame(width: 8, height: 8)
                    Text(items[i].0).font(.system(size: 12)).foregroundStyle(skin.muted).lineLimit(1)
                }
            }
        }
    }
}

/// Wrapping horizontal layout.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > maxW { y += row + spacing; x = 0; row = 0 }
            x += sz.width + spacing
            row = max(row, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.maxX { y += row + spacing; x = bounds.minX; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            row = max(row, sz.height)
        }
    }
}
