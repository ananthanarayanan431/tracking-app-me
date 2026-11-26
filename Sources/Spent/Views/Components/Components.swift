import SwiftUI

// MARK: Card

struct Card<Content: View>: View {
    @Environment(\.skin) private var skin
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(skin.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(skin.line, lineWidth: 1))
    }
}

/// Card header: title on the left, optional accessory on the right.
struct CardHeader<Accessory: View>: View {
    @Environment(\.skin) private var skin
    var title: String
    var sub: String = ""
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(skin.ink)
            Spacer(minLength: 8)
            if !sub.isEmpty { Text(sub).font(.system(size: 13)).foregroundStyle(skin.muted).lineLimit(1) }
            accessory
        }
    }
}

extension CardHeader where Accessory == EmptyView {
    init(title: String, sub: String = "") {
        self.init(title: title, sub: sub) { EmptyView() }
    }
}

struct SectionLabel: View {
    @Environment(\.skin) private var skin
    var text: String
    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(skin.muted).padding(.top, 6)
    }
}

struct Note: View {
    @Environment(\.skin) private var skin
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 13)).foregroundStyle(skin.muted).fixedSize(horizontal: false, vertical: true)
    }
}

struct EmptyNote: View {
    @Environment(\.skin) private var skin
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundStyle(skin.dim)
            .frame(maxWidth: .infinity).padding(.vertical, 22).multilineTextAlignment(.center)
    }
}

struct Tag: View {
    @Environment(\.skin) private var skin
    var text: String
    var kind: Kind?
    var body: some View {
        let c = kind.map { skin.kindColor($0) } ?? skin.muted
        Text(text).font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(c)
            .background(c.opacity(0.14), in: Capsule())
    }
}

// MARK: Buttons

enum ButtonTone { case normal, primary, accent, ghost, danger }

struct SpentButtonStyle: ButtonStyle {
    @Environment(\.skin) private var skin
    @Environment(\.isEnabled) private var enabled
    var tone: ButtonTone = .normal
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let (bg, fg, border): (Color, Color, Color) = {
            switch tone {
            case .normal: return (skin.panel2, skin.ink, skin.line2)
            case .primary: return (skin.ink, skin.bg, skin.ink)
            case .accent: return (skin.acc, skin.onAcc, skin.acc)
            case .ghost: return (.clear, skin.muted, .clear)
            case .danger: return (.clear, skin.bad, skin.bad.opacity(0.4))
            }
        }()
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, compact ? 10 : 14)
            .frame(minHeight: compact ? 28 : 34)
            .foregroundStyle(fg)
            .background(bg.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(border, lineWidth: 1))
            .opacity(enabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

extension View {
    func spentButton(_ tone: ButtonTone = .normal, compact: Bool = false) -> some View {
        buttonStyle(SpentButtonStyle(tone: tone, compact: compact))
    }
}

/// Pill-style segmented picker matching the design's `.seg` control.
struct Seg<T: Hashable>: View {
    @Environment(\.skin) private var skin
    var options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let (v, label) = options[i]
                Button { selection = v } label: {
                    Text(label).font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12).frame(minHeight: 28)
                        .foregroundStyle(selection == v ? skin.ink : skin.muted)
                        .background(selection == v ? skin.hover : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(skin.panel2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(skin.line, lineWidth: 1))
    }
}

// MARK: Ring

struct ScoreRing: View {
    @Environment(\.skin) private var skin
    var value: Int?
    var size: CGFloat = 112
    var label = "Focus score"
    var stroke: CGFloat = 9
    var color: Color?

    var body: some View {
        let p = min(1, Double(value ?? 0) / 100)
        ZStack {
            Circle().stroke(skin.track, lineWidth: stroke * size / 100)
            Circle().trim(from: 0, to: p)
                .stroke(color ?? skin.scoreColor(value), style: StrokeStyle(lineWidth: stroke * size / 100, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value.map(String.init) ?? "–").font(.system(size: size * 0.28, weight: .bold)).foregroundStyle(skin.ink)
                Text(label).font(.system(size: max(9, size * 0.095))).foregroundStyle(skin.muted)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: Icons

struct IconView: View {
    @Environment(\.skin) private var skin
    var kind: String       // "app", "site", "cat"
    var name: String
    var size: CGFloat = 28
    private var icons: IconProvider { IconProvider.shared }

    var body: some View {
        let initial = String(name.replacingOccurrences(of: "www.", with: "").first { $0.isLetter || $0.isNumber } ?? "•").uppercased()
        let color = Color(hex: kind == "cat" ? (Classifier.categoryColors[name] ?? "#5f6878") : Palette.shared.color(name))
        Group {
            if kind != "cat", let img = icons.image(kind: kind, name: name) {
                Image(nsImage: img).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                Text(initial).font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: Productive / neutral / distracting bar

struct KindBar: View {
    @Environment(\.skin) private var skin
    var summary: Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Kind.allCases) { k in
                        let v = summary.kind(k)
                        if v > 0, summary.t > 0 {
                            Rectangle().fill(skin.kindColor(k)).frame(width: max(2, geo.size.width * v / summary.t - 2))
                                .help("\(k.label) \(Fmt.duration(v))")
                        }
                    }
                }
            }
            .frame(height: 8)
            .background(skin.track)
            .clipShape(Capsule())
            HStack(spacing: 14) {
                ForEach(Kind.allCases) { k in
                    HStack(spacing: 5) {
                        Circle().fill(skin.kindColor(k)).frame(width: 7, height: 7)
                        Text(k.label).foregroundStyle(skin.muted)
                        Text(Fmt.duration(summary.kind(k))).fontWeight(.semibold).foregroundStyle(skin.ink)
                    }
                    .font(.system(size: 12))
                }
            }
        }
    }
}

// MARK: Stacked column chart

struct ColumnBar: Identifiable {
    var id: Int
    var total: Double
    var parts: [(Color, Double)]
    var tip: String
    var highlight = false
}

struct Columns: View {
    @Environment(\.skin) private var skin
    var bars: [ColumnBar]
    var labels: [String]
    var height: CGFloat = 190

    var body: some View {
        let mx = max(bars.map(\.total).max() ?? 1, 1)
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: bars.count > 40 ? 1 : 3) {
                ForEach(bars) { b in
                    VStack(spacing: 1) {
                        Spacer(minLength: 0)
                        if b.total <= 0 {
                            RoundedRectangle(cornerRadius: 2).fill(skin.track).frame(height: 3)
                        } else {
                            VStack(spacing: 1) {
                                ForEach(Array(b.parts.reversed().enumerated()), id: \.offset) { _, p in
                                    if p.1 > 0 { Rectangle().fill(p.0).frame(height: max(1, (height - 4) * p.1 / mx)) }
                                }
                            }
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                            .overlay(alignment: .top) {
                                if b.highlight { Rectangle().fill(skin.acc).frame(height: 2) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .help(b.tip)
                }
            }
            .frame(height: height)
            HStack(spacing: bars.count > 40 ? 1 : 3) {
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i]).font(.system(size: 10)).foregroundStyle(skin.dim).lineLimit(1).fixedSize()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: Ranked rows with meters

struct RankRow: View {
    @Environment(\.skin) private var skin
    var kind: String
    var name: String
    var value: Double
    var total: Double
    var maxValue: Double
    var action: () -> Void

    var body: some View {
        let isProf = kind == "prof"
        let split = name.range(of: " · ")
        let appName = isProf && split != nil ? String(name[..<split!.lowerBound]) : name
        let display = isProf && split != nil ? String(name[split!.upperBound...]) : name
        let color = Color(hex: kind == "cat" ? (Classifier.categoryColors[name] ?? "#5f6878") : Palette.shared.color(name))
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    IconView(kind: isProf ? "app" : kind, name: appName, size: 26)
                    HStack(spacing: 6) {
                        Text(display).foregroundStyle(skin.ink).lineLimit(1).truncationMode(.middle)
                        if isProf { Text(appName).foregroundStyle(skin.dim).font(.system(size: 12)).lineLimit(1) }
                    }
                    Spacer(minLength: 6)
                    Text(Fmt.duration(value)).fontWeight(.semibold).foregroundStyle(skin.ink).monospacedDigit()
                    Text("\(Fmt.percent(value, of: total))%").font(.system(size: 11)).foregroundStyle(skin.dim)
                        .frame(width: 34, alignment: .trailing)
                }
                .font(.system(size: 14))
                GeometryReader { geo in
                    Capsule().fill(skin.track)
                        .overlay(alignment: .leading) {
                            Capsule().fill(color).frame(width: geo.size.width * (maxValue > 0 ? value / maxValue : 0))
                        }
                }
                .frame(height: 4)
                .padding(.leading, 36)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Top-7 list with "Show all" toggle.
struct RankList: View {
    @Environment(\.skin) private var skin
    var entries: [(key: String, value: Double)]
    var total: Double
    var kind: String
    var empty = "Nothing tracked in this period yet."
    var limit = 7
    var onOpen: (String) -> Void
    @State private var showAll = false

    var body: some View {
        if entries.isEmpty {
            EmptyNote(empty)
        } else {
            VStack(spacing: 2) {
                let shown = showAll ? entries : Array(entries.prefix(limit))
                ForEach(shown, id: \.key) { e in
                    RankRow(kind: kind, name: e.key, value: e.value, total: total, maxValue: entries[0].value) { onOpen(e.key) }
                }
                if entries.count > limit {
                    Button(showAll ? "Show fewer" : "Show all \(entries.count)") { showAll.toggle() }
                        .spentButton(.ghost, compact: true).padding(.top, 4)
                }
            }
        }
    }
}

// MARK: Stat grid

struct StatGrid: View {
    @Environment(\.skin) private var skin
    var items: [(String, String)]
    var columns = 4

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 3) {
                    Text(items[i].0).font(.system(size: 20, weight: .semibold)).foregroundStyle(skin.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Text(items[i].1).font(.system(size: 12)).foregroundStyle(skin.muted).lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(skin.panel2, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: Progress meter

struct Meter: View {
    @Environment(\.skin) private var skin
    var fraction: Double
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            Capsule().fill(skin.track)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: geo.size.width * min(1, max(0, fraction)))
                }
        }
        .frame(height: height)
    }
}

// MARK: Swatches

struct SwatchPicker: View {
    var colors: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(colors, id: \.self) { c in
                Circle().fill(Color(hex: c)).frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white, lineWidth: selection == c ? 2 : 0))
                    .onTapGesture { selection = c }
            }
        }
    }
}

// MARK: Field label

struct Labeled<Content: View>: View {
    @Environment(\.skin) private var skin
    var label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(skin.muted)
            content
        }
    }
}

extension View {
    /// Text field look from the design.
    func spentField() -> some View { modifier(FieldStyle()) }
}

struct FieldStyle: ViewModifier {
    @Environment(\.skin) private var skin
    func body(content: Content) -> some View {
        content.textFieldStyle(.plain)
            .padding(.horizontal, 10).frame(minHeight: 32)
            .background(skin.panel2, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(skin.line2, lineWidth: 1))
    }
}
