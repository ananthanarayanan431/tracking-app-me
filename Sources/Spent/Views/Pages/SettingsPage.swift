import SwiftUI

struct SettingsPage: View {
    var body: some View {
        VStack(spacing: 16) {
            AppearanceCard()
            SpanRow(spans: [1, 1]) {
                TrackerCard()
                PhoneCard()
            }
            LabelsCard()
            SpanRow(spans: [7, 5]) {
                AwaySettingsCard()
                PrivacyCard()
            }
            SpanRow(spans: [1, 1]) {
                ManualPhoneCard()
                DataCard()
            }
        }
    }
}

// MARK: Appearance

private struct AppearanceCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let cur = model.settings.theme ?? "coral"
        Card {
            CardHeader(title: "Appearance", sub: "Pick a colour combination")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(Skin.all, id: \.id) { s in
                    let on = s.id == cur
                    Button {
                        model.settings.theme = s.id
                        model.settings.accent = nil
                        apply()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                s.panel.frame(width: 36)
                                VStack(alignment: .leading, spacing: 5) {
                                    RoundedRectangle(cornerRadius: 3).fill(on && model.settings.accent != nil ? Color(hex: model.settings.accent!) : s.acc)
                                        .frame(width: 60, height: 11)
                                    RoundedRectangle(cornerRadius: 2).fill(s.panel).frame(width: 70, height: 6)
                                    RoundedRectangle(cornerRadius: 2).fill(s.panel).frame(width: 45, height: 6)
                                }
                                .padding(8)
                                Spacer(minLength: 0)
                            }
                            .frame(height: 70)
                            .background(s.bg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                            Text(s.name).font(.system(size: 13, weight: .medium))
                        }
                        .padding(10)
                        .background(skin.panel2, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? skin.acc : skin.line, lineWidth: on ? 2 : 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 12) {
                ColorPicker("Accent colour", selection: Binding(
                    get: { Color(hex: model.settings.accent ?? Skin.defaultAccents[cur] ?? "#ff6a55") },
                    set: { model.settings.accent = $0.hexString; apply() }
                ), supportsOpacity: false)
                if model.settings.accent != nil {
                    Button("Use theme accent") { model.settings.accent = nil; apply() }.spentButton(.ghost, compact: true)
                }
            }
        }
    }

    private func apply() {
        model.saveSettings()
        Theme.applyDockIcon(settings: model.settings)
    }
}

// MARK: Tracker

private struct TrackerCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var loginOn = LoginItem.enabled

    var body: some View {
        Card {
            CardHeader(title: "Mac tracker")
            Group {
                if model.paused {
                    Text("Paused").foregroundStyle(skin.warn).bold() + Text(" · nothing is being recorded")
                } else if let c = model.current {
                    Text("● Recording").foregroundStyle(skin.good).bold() + Text(" · \(c.app)\(c.dom.isEmpty ? "" : " · " + c.dom)")
                } else if !model.tracker.ownsLock {
                    Text("Another tracker is recording").foregroundStyle(skin.warn).bold()
                } else {
                    Text("Running").foregroundStyle(skin.good).bold() + Text(" · you look idle right now")
                }
            }
            .font(.system(size: 14))
            Note("Spent records the frontmost app every 5 seconds, plus the site and page title in Chrome, Safari, Arc, Brave, Edge and Comet. It keeps recording from the menu bar when you close this window.")
            Toggle(isOn: Binding(get: { loginOn }, set: { on in
                if let err = LoginItem.set(on) { model.toast(err) }
                loginOn = LoginItem.enabled
            })) {
                Text("Start Spent at login (so tracking never stops)")
            }
            .toggleStyle(.switch)
            HStack(spacing: 10) {
                Button(model.paused ? "Resume" : "Pause") { model.togglePause() }.spentButton(.primary)
                Picker("", selection: Binding(get: { model.idleSeconds }, set: { model.idleSeconds = $0 })) {
                    ForEach([(60, "Idle after 1 min"), (180, "Idle after 3 min"), (300, "Idle after 5 min"), (600, "Idle after 10 min"), (1800, "Idle after 30 min")], id: \.0) {
                        Text($0.1).tag($0.0)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            }
            Note("The first time a browser is in front, macOS asks whether Spent may control it: allow it, or only the browser name is recorded. No keystrokes or screen content are captured.")
        }
    }
}

// MARK: iPhone

private struct PhoneCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var path = ""
    @State private var showShortcuts = false

    var body: some View {
        Card {
            CardHeader(title: "iPhone")
            status
            Note("Spent reads the iPhone app usage that Screen Time syncs to this Mac: every app, automatically, nothing to install on the phone and nothing is blocked. Today’s numbers arrive in batches, so they can lag a few hours behind; past days fill in completely.")
            switch model.phone.screenTime {
            case .noAccess:
                VStack(alignment: .leading, spacing: 6) {
                    step(1, "Click the button below, then + and choose Spent from your Applications folder.")
                    step(2, "Turn Spent’s switch on, then quit and reopen Spent.")
                }
                HStack {
                    Button("Open Full Disk Access settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                    .spentButton(.accent)
                    Button("Check again") { model.loadBase() }.spentButton()
                }
            case .noDevices:
                VStack(alignment: .leading, spacing: 6) {
                    step(1, "iPhone: Settings › Screen Time › turn on Share Across Devices.")
                    step(2, "Mac: System Settings › Screen Time › turn on Share across devices (same Apple ID).")
                    step(3, "Wait a while for the first sync, then click Check again.")
                }
                Button("Check again") { model.loadBase() }.spentButton()
            default:
                EmptyView()
            }
            DisclosureGroup(isExpanded: $showShortcuts) {
                VStack(alignment: .leading, spacing: 8) {
                    Note("Optional: a Shortcuts automation per app writes open/close times to iCloud Drive straight away. Spent uses it only for the time after the last Screen Time sync, so nothing is counted twice.")
                    ForEach(Array([
                        "On iPhone: Shortcuts › Automation › New Automation › App.",
                        "Pick an app, tick Is Opened and Is Closed, choose Run Immediately, then New Blank Automation.",
                        "Add Format Date (Current Date, ISO 8601, include time).",
                        "Add Text: Formatted Date|AppName",
                        "Add Append to Text File → Spent/phone.txt, Make New Line on.",
                    ].enumerated()), id: \.offset) { i, t in step(i + 1, t) }
                    if model.phone.shortcutEvents > 0 {
                        Text("Shortcuts log: \(model.phone.shortcutEvents) lines").font(.system(size: 12)).foregroundStyle(skin.good)
                    }
                    HStack {
                        TextField("Custom path to phone.txt (optional)", text: $path).spentField()
                        Button("Save") {
                            model.phoneCustomPath = path.trimmingCharacters(in: .whitespaces)
                            Storage.writeText("phone-path", model.phoneCustomPath)
                            model.loadBase()
                        }
                        .spentButton()
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Same-day top-up with Shortcuts (optional)").font(.system(size: 13, weight: .medium))
            }
        }
        .onAppear { path = model.phoneCustomPath }
    }

    @ViewBuilder private var status: some View {
        switch model.phone.screenTime {
        case .ok(_, let events, let last):
            (Text("● Connected via Screen Time").foregroundStyle(skin.good).bold()
                + Text(" · \(events.formatted()) events\(last.map { ", synced up to " + Date(timeIntervalSince1970: $0).formatted(date: .abbreviated, time: .shortened) } ?? "")"))
                .font(.system(size: 14))
        case .noAccess:
            Text("Spent needs Full Disk Access to read iPhone usage").foregroundStyle(skin.warn).bold().font(.system(size: 14))
        case .noDevices:
            Text("No iPhone data synced to this Mac yet").foregroundStyle(skin.warn).bold().font(.system(size: 14))
        case .unreadable(let why):
            Text("iPhone data couldn’t be read: \(why)").foregroundStyle(skin.bad).bold().font(.system(size: 14))
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n).").foregroundStyle(skin.muted).frame(width: 18, alignment: .trailing)
            Text(text)
        }
        .font(.system(size: 13))
    }
}

// MARK: Labels

private struct LabelsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let _ = model.revision
        let M = Summarizer.merge(model.periodData(DayRange.lastN(30)).map { $0.pick(.all) })
        let items: [(kind: String, name: String, v: Double)] =
            M.bp.sortedDesc.map { ("prof", $0.key, $0.value) }
            + M.a.sortedDesc.prefix(30).map { ("app", $0.key, $0.value) }
            + M.d.sortedDesc.prefix(30).map { ("site", $0.key, $0.value) }
        Card {
            CardHeader(title: "Labels", sub: "Your top apps and sites from the last 30 days")
            Note("Choose a category and whether it counts as productive, neutral or distracting. This drives the focus score, goals and category limits.")
            if items.isEmpty {
                EmptyNote("Nothing tracked yet.")
            } else {
                HStack {
                    Text("App or site").frame(maxWidth: .infinity, alignment: .leading)
                    Text("30 days").frame(width: 70, alignment: .trailing)
                    Text("Category").frame(width: 170, alignment: .leading)
                    Text("Counts as").frame(width: 140, alignment: .leading)
                    Text("").frame(width: 60)
                }
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(skin.dim)
                LazyVStack(spacing: 0) {
                    ForEach(items, id: \.name) { it in LabelRow(kind: it.kind, name: it.name, value: it.v) }
                }
            }
        }
    }
}

struct LabelRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var kind: String
    var name: String
    var value: Double?

    var body: some View {
        let key = kind + ":" + name
        let o = model.settings.overrides[key]
        let split = name.range(of: " · ")
        let (cat, type) = model.labelFor(kind: kind, name: name)
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    if kind == "prof", let r = split {
                        IconView(kind: "app", name: String(name[..<r.lowerBound]), size: 20)
                        Text("\(name[r.upperBound...]) (\(name[..<r.lowerBound]) profile)").lineLimit(1)
                    } else {
                        IconView(kind: kind, name: name, size: 20)
                        Text(name).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let value { Text(Fmt.duration(value)).monospacedDigit().frame(width: 70, alignment: .trailing) }
                Picker("", selection: Binding(get: { cat }, set: { model.setOverride(key, cat: $0) })) {
                    ForEach(Classifier.categories, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().frame(width: 170)
                Picker("", selection: Binding(get: { type }, set: { model.setOverride(key, type: $0) })) {
                    ForEach(Kind.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().frame(width: 140)
                Group {
                    if o?.cat != nil || o?.type != nil {
                        Button("Reset") { model.resetOverride(key) }.spentButton(.ghost, compact: true)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 60)
            }
            .font(.system(size: 13))
            .padding(.vertical, 5)
            Divider().overlay(skin.line)
        }
    }
}

extension AppModel {
    func labelFor(kind: String, name: String) -> (String, Kind) {
        switch kind {
        case "app": return classifier.classify(app: name)
        case "site": return classifier.classify(app: "", dom: name)
        case "prof":
            if let r = name.range(of: " · ") {
                return classifier.classify(app: String(name[..<r.lowerBound]), prof: String(name[r.upperBound...]))
            }
            return classifier.classify(app: name)
        default:
            return (name, Classifier.defaultKind[name] ?? .n)
        }
    }

    func setOverride(_ key: String, cat: String? = nil, type: Kind? = nil) {
        var o = settings.overrides[key] ?? Override()
        if let cat {
            o.cat = cat
            if o.type == nil { o.type = Classifier.defaultKind[cat] }
        }
        if let type { o.type = type }
        settings.overrides[key] = o
        overridesChanged()
        toast("Label saved")
    }

    func resetOverride(_ key: String) {
        settings.overrides[key] = nil
        overridesChanged()
    }
}

// MARK: Away

private struct AwaySettingsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var newName = ""
    @State private var newHabit = ""
    @State private var newColor = AppModel.habitColors[0]

    var body: some View {
        Card {
            CardHeader(title: "Away from the screen")
            Note("When you come back after a long break, Spent asks what you were doing. Link an activity to a habit and logging it ticks the habit too.")
            Toggle("Ask me when I come back", isOn: Binding(get: { model.awayOn }, set: { model.settings.awayOn = $0; model.saveSettings() }))
                .toggleStyle(.switch)
            Toggle("Bring Spent to the front to ask", isOn: Binding(get: { model.settings.awayPop != false }, set: { model.settings.awayPop = $0; model.saveSettings() }))
                .toggleStyle(.switch)
            HStack {
                Text("Ask after a break of at least")
                Picker("", selection: Binding(get: { model.settings.awayMin ?? 20 }, set: { model.settings.awayMin = $0; model.saveSettings(); model.revision += 1 })) {
                    ForEach([10, 15, 20, 30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden().frame(width: 100)
            }
            SectionLabel(text: "Activities")
            ForEach(model.activities) { a in
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: a.color)).frame(width: 10, height: 10)
                    Text(a.name).fontWeight(.semibold)
                    Spacer()
                    Picker("", selection: Binding(get: { a.habit }, set: { model.linkActivity(a.id, habit: $0) })) {
                        Text("No habit").tag("")
                        ForEach(model.habits) { Text("Ticks: \($0.name)").tag($0.id) }
                    }
                    .labelsHidden().frame(width: 200)
                    Button("Remove") { model.removeActivity(a.id) }.spentButton(.ghost, compact: true)
                }
                .font(.system(size: 13))
            }
            HStack(alignment: .bottom, spacing: 10) {
                Labeled(label: "New activity") { TextField("Swim", text: $newName).spentField() }
                Labeled(label: "Ticks habit") {
                    Picker("", selection: $newHabit) {
                        Text("None").tag("")
                        ForEach(model.habits) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden().frame(width: 150)
                }
                Labeled(label: "Colour") { SwatchPicker(colors: AppModel.habitColors, selection: $newColor) }
                Button("Add") {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    model.addActivity(name: n, color: newColor, habit: newHabit)
                    newName = ""
                }
                .spentButton(.primary)
            }
        }
    }
}

// MARK: Privacy

private struct PrivacyCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var key = ""
    @State private var hasKey = Keychain.hasKey

    var body: some View {
        Card {
            CardHeader(title: "Privacy") {
                Text("● Private to you").font(.system(size: 12, weight: .medium)).foregroundStyle(skin.good)
            }
            Note("Spent runs only on this MacBook. Your history, habits, campaigns and away log live in ~/.spent and are never uploaded.")
            Toggle(isOn: Binding(get: { model.settings.privacy.ai }, set: { model.settings.privacy.ai = $0; model.saveSettings(); model.toast("Privacy setting saved") })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI summaries")
                    Note("Sends this screen’s totals (not raw history) to Claude when you press the button")
                }
            }
            .toggleStyle(.switch)
            Toggle(isOn: Binding(get: { model.settings.privacy.logos }, set: {
                model.settings.privacy.logos = $0
                IconProvider.shared.allowNetwork = $0
                model.saveSettings()
                model.toast("Privacy setting saved")
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Website logos and iPhone app names")
                    Note("Asks Google for a site’s icon, and Apple’s App Store for an iPhone app’s name and icon, once each. Off = only logos of apps on this Mac")
                }
            }
            .toggleStyle(.switch)
            SectionLabel(text: "Anthropic API key (for AI summaries)")
            HStack {
                SecureField(hasKey ? "Saved in Keychain — paste to replace" : "sk-ant-…", text: $key).spentField()
                Button("Save") {
                    Keychain.setAPIKey(key.trimmingCharacters(in: .whitespacesAndNewlines))
                    key = ""
                    hasKey = Keychain.hasKey
                    model.toast(hasKey ? "API key saved to Keychain" : "API key removed")
                }
                .spentButton()
                if hasKey {
                    Button("Remove") { Keychain.setAPIKey(nil); hasKey = false; model.toast("API key removed") }.spentButton(.ghost, compact: true)
                }
            }
        }
    }
}

// MARK: Manual iPhone time

private struct ManualPhoneCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var date = Date()
    @State private var app = ""
    @State private var minutes = ""

    var body: some View {
        Card {
            CardHeader(title: "Add iPhone time by hand")
            Note("For apps without an automation, copy the numbers from Settings › Screen Time.")
            HStack(spacing: 8) {
                DatePicker("", selection: $date, displayedComponents: .date).labelsHidden().datePickerStyle(.field)
                TextField("App, e.g. Instagram", text: $app).spentField()
                TextField("Minutes", text: $minutes).spentField().frame(width: 80)
                Button("Add") {
                    let a = app.trimmingCharacters(in: .whitespaces)
                    guard !a.isEmpty, let m = Double(minutes), m > 0 else { return }
                    model.manual.append(ManualPhone(date: Fmt.key(date), app: a, min: m))
                    Storage.write("phone-manual.json", model.manual)
                    model.revision += 1
                    app = ""; minutes = ""
                    model.toast("Added")
                }
                .spentButton(.primary)
            }
            ForEach(Array(model.manual.enumerated().reversed().prefix(6)), id: \.offset) { i, m in
                HStack(spacing: 10) {
                    IconView(kind: "app", name: m.app, size: 20)
                    Text(m.app)
                    Text(m.date).font(.system(size: 12)).foregroundStyle(skin.muted)
                    Spacer()
                    Text(Fmt.duration(m.min * 60)).fontWeight(.semibold)
                    Button("Remove") {
                        model.manual.remove(at: i)
                        Storage.write("phone-manual.json", model.manual)
                        model.revision += 1
                    }
                    .spentButton(.ghost, compact: true)
                }
                .font(.system(size: 13))
            }
        }
    }
}

// MARK: Data

private struct DataCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        Card {
            CardHeader(title: "Your data")
            Note("Everything stays on this Mac in ~/.spent: one file per day, nothing uploaded. AI summaries send only the totals on screen to Claude.")
            FlowRow(spacing: 8) {
                Button("Export last 30 days (CSV)") { model.exportCSV() }.spentButton()
                Button("Open data folder") { NSWorkspace.shared.open(Storage.root) }.spentButton()
                Button("Refresh") { model.loadBase() }.spentButton()
                Button("Retry logos") { IconProvider.shared.retry(); model.toast("Fetching missing logos…") }.spentButton()
            }
            Note("\(model.daysAvail.count) days of Mac history on disk. \(IconProvider.shared.loadedCount) logos loaded.")
        }
    }
}
