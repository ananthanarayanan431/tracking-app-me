import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 232)
            Rectangle().fill(skin.line).frame(width: 1)
            VStack(spacing: 0) {
                TopBar()
                ScrollView {
                    page
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                        .frame(maxWidth: 1500)
                        .frame(maxWidth: .infinity)
                }
                .id(model.tab)
            }
        }
        .background(background)
        .foregroundStyle(skin.ink)
        .tint(skin.acc)
        .overlay(alignment: .bottom) { ToastView() }
        .sheet(item: $model.detail) { target in
            DetailSheet(target: target)
                .environment(model)
                .environment(\.skin, skin)
        }
        .sheet(item: $model.habitEntryTarget) { t in
            HabitEntrySheet(target: t)
                .environment(model)
                .environment(\.skin, skin)
        }
        .sheet(item: $model.awayPrompt) { gap in
            AwaySheet(gap: gap)
                .environment(model)
                .environment(\.skin, skin)
        }
        .onKeyPress(.leftArrow) {
            guard model.tab == .overview else { return .ignored }
            model.stepPeriod(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard model.tab == .overview else { return .ignored }
            model.stepPeriod(1)
            return .handled
        }
    }

    @ViewBuilder private var page: some View {
        switch model.tab {
        case .overview: OverviewPage()
        case .insights: InsightsPage()
        case .focus: FocusPage()
        case .habits: HabitsPage()
        case .campaigns: CampaignsPage()
        case .deskbreak: DeskBreakPage()
        case .aadat: AadatPage()
        case .limits: LimitsPage()
        case .settings: SettingsPage()
        }
    }

    private var background: some View {
        ZStack {
            skin.bg
            RadialGradient(colors: [skin.acc.opacity(0.10), .clear], center: UnitPoint(x: 0.12, y: -0.08), startRadius: 0, endRadius: 700)
            RadialGradient(colors: [skin.blue.opacity(0.07), .clear], center: UnitPoint(x: 1, y: 0), startRadius: 0, endRadius: 600)
        }
        .ignoresSafeArea()
    }
}

extension AppModel {
    func stepPeriod(_ n: Int) {
        let next = DayRange.shift(period, anchor, by: n)
        if DayRange.period(period, anchor: next).start <= Date() { anchor = next }
    }
}

struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                BrandMark(size: 28)
                Text("Spent").font(.system(size: 21, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.top, 44)
            .padding(.bottom, 18)

            ForEach(Tab.allCases) { t in
                Button { model.tab = t } label: {
                    HStack(spacing: 12) {
                        Image(systemName: t.symbol).frame(width: 18)
                        Text(t.navTitle)
                        Spacer()
                        if let n = badge(t), n > 0 {
                            Text("\(n)").font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6).frame(minHeight: 18)
                                .background(skin.acc, in: Capsule()).foregroundStyle(skin.onAcc)
                        }
                    }
                    .font(.system(size: 14, weight: model.tab == t ? .semibold : .regular))
                    .foregroundStyle(model.tab == t ? skin.ink : skin.muted)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 38)
                    .background(model.tab == t ? skin.hover : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            SideFooter()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 18)
        .background(LinearGradient(colors: [skin.side, skin.bg], startPoint: .top, endPoint: .bottom))
    }

    private func badge(_ t: Tab) -> Int? {
        switch t {
        case .campaigns: return model.campaignsDue
        case .limits: return model.limitsOver
        default: return nil
        }
    }
}

struct BrandMark: View {
    @Environment(\.skin) private var skin
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(skin.acc)
            Circle().stroke(skin.onAcc, lineWidth: size * 0.086).frame(width: size * 0.54, height: size * 0.54)
            Path { p in
                let c = CGPoint(x: size / 2, y: size / 2)
                p.move(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y - size * 0.16))
                p.move(to: c); p.addLine(to: CGPoint(x: c.x + size * 0.107, y: c.y + size * 0.071))
            }
            .stroke(skin.onAcc, style: StrokeStyle(lineWidth: size * 0.086, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// Focus timer chip + live recording pill.
struct SideFooter: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.focus.running || model.focus.remaining < model.focus.planned {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let label = model.focus.label.isEmpty ? "" : " · " + model.focus.label
                    Text("\(model.focus.running ? "Focusing" : "Paused") · \(Fmt.mmss(model.focusRemaining))\(label)")
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                        .padding(.horizontal, 10).frame(minHeight: 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(skin.good.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(skin.good)
                        .onTapGesture { model.tab = .focus }
                }
            }
            TimelineView(.periodic(from: .now, by: 5)) { _ in
                let on = model.current != nil && !model.paused
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Circle().fill(on ? skin.good : skin.dim).frame(width: 8, height: 8)
                            .shadow(color: on ? skin.good : .clear, radius: 4)
                        Text(model.paused ? "Paused" : model.current.map { $0.dom.isEmpty ? $0.app : $0.dom } ?? "Idle")
                            .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    }
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(skin.muted).lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(skin.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(skin.line, lineWidth: 1))
            }
        }
    }

    private var subtitle: String {
        if model.paused { return "Nothing is recorded" }
        if let c = model.current { return "\(c.app) · \(Fmt.duration(Date().timeIntervalSince1970 - c.s))" }
        return model.tracker.ownsLock ? "Waiting for activity" : "Another tracker is recording"
    }
}

struct TopBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 12) {
            Text(model.tab.title).font(.system(size: 26, weight: .bold))
            Spacer(minLength: 12)
            switch model.tab {
            case .overview:
                Seg(options: PeriodView.allCases.map { ($0, $0.label) }, selection: Binding(
                    get: { model.period }, set: { model.period = $0; model.anchor = Date() }))
                HStack(spacing: 4) {
                    Button { model.stepPeriod(-1) } label: { Image(systemName: "chevron.left") }.spentButton(.ghost, compact: true)
                    Text(model.currentRange.label).font(.system(size: 14, weight: .semibold)).frame(minWidth: 120)
                    Button { model.stepPeriod(1) } label: { Image(systemName: "chevron.right") }.spentButton(.ghost, compact: true)
                        .disabled(model.currentRange.end > Date())
                }
                deviceSeg
            case .insights:
                Seg(options: [(7, "7 days"), (30, "30 days"), (90, "90 days"), (365, "1 year")], selection: $model.insightsWindow)
                deviceSeg
            case .campaigns:
                Button("+ New campaign") { model.campaignFormOpen = true; model.editingCampaign = nil }.spentButton(.accent)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 38)
        .padding(.bottom, 18)
    }

    private var deviceSeg: some View {
        @Bindable var model = model
        return Seg(options: DeviceFilter.allCases.map { ($0, $0.label) }, selection: $model.dev)
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        if let t = model.toastText {
            Text(t).font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(skin.ink, in: Capsule())
                .foregroundStyle(skin.bg)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                .padding(.bottom, 26)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: model.toastText)
        }
    }
}
