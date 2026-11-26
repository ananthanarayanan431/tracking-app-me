import SwiftUI

struct LimitsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var target = ""
    @State private var custom = ""
    @State private var minutes = "60"

    var body: some View {
        let _ = model.revision
        let S = model.todayAll()
        let M = Summarizer.merge(model.periodData(DayRange.lastN(30)).map { $0.pick(.all) })
        let over = model.settings.limits.filter { model.usage($0, in: S) >= $0.min * 60 }.count
        VStack(spacing: 16) {
            Card {
                CardHeader(title: "Alerts") {
                    if model.notificationsAllowed {
                        Text("● Mac notifications on").font(.system(size: 12, weight: .medium)).foregroundStyle(skin.good)
                    } else if !Notifier.shared.available {
                        Text("Notifications work in the installed app").font(.system(size: 12)).foregroundStyle(skin.muted)
                    } else if Notifier.shared.status == .denied {
                        Button("Allow notifications") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                        }
                        .spentButton(compact: true)
                    } else {
                        Button("Turn on notifications") { Task { await model.enableNotifications() } }.spentButton(.accent, compact: true)
                    }
                }
                Note("You get a notification at 80% of a limit, another when you hit it, and a reminder every 15 minutes while you keep using it past the limit. Limits count Mac and iPhone together and reset at midnight.")
                HStack(spacing: 10) {
                    Picker("", selection: $target) {
                        Text("Choose an app, site or category").tag("")
                        Section("Apps") { ForEach(M.a.sortedDesc.prefix(40), id: \.key) { Text($0.key).tag("app:" + $0.key) } }
                        Section("Websites") { ForEach(M.d.sortedDesc.prefix(40), id: \.key) { Text($0.key).tag("site:" + $0.key) } }
                        Section("Categories") { ForEach(Classifier.categories, id: \.self) { Text($0).tag("cat:" + $0) } }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                    TextField("…or type an app or site (e.g. youtube.com)", text: $custom).spentField()
                    TextField("60", text: $minutes).spentField().frame(width: 70)
                    Text("min").foregroundStyle(skin.muted)
                    Button("Add limit", action: add).spentButton(.primary)
                }
            }
            Card {
                CardHeader(title: "Today’s limits", sub: model.settings.limits.isEmpty ? "" : "\(over) of \(model.settings.limits.count) reached")
                if model.settings.limits.isEmpty {
                    EmptyNote("No limits yet. A good start: social apps at 45 minutes a day.")
                }
                ForEach(model.settings.limits) { L in LimitRow(limit: L, used: model.usage(L, in: S)) }
            }
        }
    }

    private func add() {
        let m = Double(minutes) ?? 0
        guard m > 0 else { return }
        if !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            model.addLimit(custom: custom, minutes: m)
            custom = ""
        } else if let i = target.firstIndex(of: ":"), let kind = LimitKind(rawValue: String(target[..<i])) {
            model.setLimit(kind: kind, name: String(target[target.index(after: i)...]), minutes: m)
        }
    }
}

private struct LimitRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var limit: Limit
    var used: Double
    @State private var minutes = ""

    var body: some View {
        let lim = limit.min * 60
        let p = min(1, used / lim)
        let col = p >= 1 ? skin.bad : p >= 0.8 ? skin.warn : skin.good
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                IconView(kind: limit.kind.rawValue, name: limit.name, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(limit.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Tag(text: limit.kind.label)
                    }
                    HStack(spacing: 0) {
                        Text("\(Fmt.duration(used)) used of \(Fmt.duration(lim)) · ")
                        if p >= 1 {
                            Text("\(Fmt.duration(used - lim)) over").foregroundStyle(skin.bad)
                        } else {
                            Text("\(Fmt.duration(lim - used)) left")
                        }
                    }
                    .font(.system(size: 12)).foregroundStyle(skin.muted)
                }
                Spacer()
                TextField("", text: $minutes).spentField().frame(width: 64)
                    .onSubmit { model.updateLimit(limit.id, minutes: Double(minutes) ?? 0) }
                Text("min").font(.system(size: 12)).foregroundStyle(skin.muted)
                Button("Remove") { model.removeLimit(limit.id) }.spentButton(.ghost, compact: true)
            }
            Meter(fraction: p, color: col, height: 6)
        }
        .padding(.vertical, 6)
        .onAppear { minutes = MenuBarContent.num(limit.min) }
    }
}
