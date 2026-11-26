import SwiftUI

struct CampaignsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let C = model.campaigns
        let active = C.filter { model.campaignStats($0).state != .finished }
        let finished = C.filter { model.campaignStats($0).state == .finished }
        let showForm = model.campaignFormOpen || model.editingCampaign != nil || C.isEmpty
        VStack(spacing: 16) {
            if showForm { CampaignForm() }
            if active.isEmpty, !C.isEmpty {
                Card { EmptyNote("No active campaigns. Start a new one.") }
            }
            ForEach(active) { CampaignCard(campaign: $0) }
            if !finished.isEmpty {
                Card {
                    CardHeader(title: "Finished campaigns", sub: "\(finished.count)")
                    ForEach(finished) { c in
                        let s = model.campaignStats(c)
                        HStack(spacing: 10) {
                            Circle().fill(Color(hex: c.color)).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.system(size: 14, weight: .semibold))
                                Text("\(Fmt.shortDate(c.start)) – \(Fmt.shortDate(s.end)) · \(s.done) of \(c.days) days · best streak \(s.best)")
                                    .font(.system(size: 12)).foregroundStyle(skin.muted)
                            }
                            Spacer()
                            Text("\(s.rate)%").font(.system(size: 18, weight: .semibold)).foregroundStyle(skin.scoreColor(s.rate))
                            ConfirmDeleteButton { model.deleteCampaign(c.id) }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct CampaignCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var campaign: Campaign

    var body: some View {
        let c = campaign
        let s = model.campaignStats(c)
        let t = Fmt.todayKey
        let col = Color(hex: c.color)
        let linked = model.habit(c.habit)
        let status: String = {
            switch s.state {
            case .upcoming: return "Starts \(Fmt.shortDate(c.start))"
            case .finished: return "Finished \(Fmt.shortDate(s.end))"
            case .active: return "Day \(s.dayN) of \(c.days)"
            }
        }()
        Card(padding: 22) {
            HStack(alignment: .center, spacing: 20) {
                ScoreRing(value: s.rate, size: 104, label: "consistent", color: col)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(status) · ends \(Fmt.shortDate(s.end))").font(.system(size: 12)).foregroundStyle(skin.muted)
                    Text(c.name).font(.system(size: 24, weight: .bold))
                    if !c.goal.isEmpty { Note(c.goal) }
                    if let h = linked { Note("Auto-dots on days you tick \(h.name)") }
                }
                Spacer()
                if s.state == .active {
                    Button { model.toggleCampaign(c.id, t) } label: {
                        HStack(spacing: 8) {
                            if s.todayDone { Icon(.check, size: 16) }
                            Text(s.todayDone ? "Done today" : "Put today’s dot")
                        }
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 18).frame(minHeight: 48)
                            .background(s.todayDone ? col : col.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(s.todayDone ? Color.black.opacity(0.8) : col)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(col, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Meter(fraction: Double(s.dayN) / Double(max(1, c.days)), color: col, height: 6)
            HStack(spacing: 10) {
                ForEach([(s.done, "days done"), (s.missed, "missed"), (s.cur, "current streak"), (s.best, "best streak"), (s.left, "days left")], id: \.1) { v, l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(v)").font(.system(size: 20, weight: .bold))
                        Text(l).font(.system(size: 11)).foregroundStyle(skin.muted)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(skin.panel2, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30, maximum: 36), spacing: 5)], spacing: 5) {
                ForEach(Array(c.dayKeys.enumerated()), id: \.offset) { i, k in
                    let m = model.campaignMarked(c, k)
                    let fut = k > t
                    let miss = !m && k < t
                    let auto = m && model.clog[c.id]?[k] == nil
                    Button { model.toggleCampaign(c.id, k) } label: {
                        Text("\(i + 1)").font(.system(size: 11, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .foregroundStyle(m ? Color.black.opacity(0.8) : miss ? skin.bad : skin.muted)
                            .background(m ? col : skin.panel2, in: Circle())
                            .overlay(Circle().stroke(k == t ? skin.ink : miss ? skin.bad.opacity(0.4) : skin.line, lineWidth: k == t ? 1.5 : 1))
                            .opacity(fut ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(fut)
                    .help("Day \(i + 1) · \(Fmt.weekdayName(k)) \(Fmt.shortDate(k))\(m ? (auto ? " · from habit" : " · done") : miss ? " · missed" : fut ? "" : " · today")")
                }
            }
            HStack {
                Spacer()
                Button("Edit") { model.editingCampaign = c.id; model.campaignFormOpen = true }.spentButton(.ghost, compact: true)
                ConfirmDeleteButton { model.deleteCampaign(c.id) }
            }
        }
    }
}

private struct CampaignForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var name = ""
    @State private var goal = ""
    @State private var start = Date()
    @State private var days = "30"
    @State private var habit = ""
    @State private var color = AppModel.habitColors[2]
    @State private var loadedFor: String? = "–"

    var body: some View {
        let editing = model.campaigns.first { $0.id == model.editingCampaign }
        Card {
            CardHeader(title: editing == nil ? "Start a campaign" : "Edit campaign") {
                if !model.campaigns.isEmpty {
                    Button("Close") { model.campaignFormOpen = false; model.editingCampaign = nil }.spentButton(.ghost, compact: true)
                }
            }
            Note("A campaign is a run of days you commit to: run every day for 30 days, no social media before noon for 21 days, ship something daily for 100 days. Put a dot each day you make it; Spent tracks how consistent you are.")
            HStack(alignment: .bottom, spacing: 10) {
                Labeled(label: "Campaign name") { TextField("Run every day", text: $name).spentField() }
                Labeled(label: "What counts as a dot? (optional)") { TextField("At least 3 km, any pace", text: $goal).spentField() }
            }
            HStack(alignment: .bottom, spacing: 16) {
                Labeled(label: "Start date") {
                    DatePicker("", selection: $start, displayedComponents: .date).labelsHidden().datePickerStyle(.field)
                }
                Labeled(label: "Length") {
                    HStack(spacing: 6) {
                        ForEach([7, 21, 30, 66, 75, 100], id: \.self) { p in
                            Button("\(p) days") { days = "\(p)" }.spentButton(days == "\(p)" ? .primary : .normal, compact: true)
                        }
                        TextField("30", text: $days).spentField().frame(width: 70)
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 16) {
                Labeled(label: "Fill dots automatically from a habit (optional)") {
                    Picker("", selection: $habit) {
                        Text("No, I’ll dot it myself").tag("")
                        ForEach(model.habits) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }
                Labeled(label: "Colour") { SwatchPicker(colors: AppModel.habitColors, selection: $color) }
            }
            Button(editing == nil ? "Start campaign" : "Save changes") { save(editing) }
                .spentButton(.primary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear { load(editing) }
        .onChange(of: model.editingCampaign) { load(model.campaigns.first { $0.id == model.editingCampaign }) }
    }

    private func load(_ c: Campaign?) {
        guard loadedFor != c?.id else { return }
        loadedFor = c?.id
        name = c?.name ?? ""
        goal = c?.goal ?? ""
        start = c.map { Fmt.date($0.start) } ?? Date()
        days = "\(c?.days ?? 30)"
        habit = c?.habit ?? ""
        color = c?.color ?? AppModel.habitColors[(model.campaigns.count + 2) % AppModel.habitColors.count]
    }

    private func save(_ editing: Campaign?) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let d = max(1, min(1000, Int(days) ?? 30))
        let c = Campaign(id: editing?.id ?? "c" + String(Int(Date().timeIntervalSince1970), radix: 36),
                         name: n, goal: goal.trimmingCharacters(in: .whitespaces), start: Fmt.key(start),
                         days: d, color: color, habit: habit)
        model.saveCampaign(c)
        model.editingCampaign = nil
        model.campaignFormOpen = false
        loadedFor = "–"
        load(nil)
    }
}
