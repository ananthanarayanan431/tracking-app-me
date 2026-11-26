import SwiftUI

/// AI summary (Overview) and AI coach (Insights). Prompts contain only aggregated totals.
extension AppModel {
    private func top(_ o: [String: Double]) -> String {
        o.sortedDesc.prefix(15).map { "\($0.key): \(Int($0.value / 60)) min" }.joined(separator: "; ")
    }

    /// Shared context: profiles, away log, habits, apps, sites, categories, focus figures.
    func aiBase(_ S: Summary, keys: [String]) -> String {
        let hab = habits.map { h -> String in
            let sk = keys.filter { h.scheduled($0) }
            let amount = h.kind == .number ? " (\(MenuBarContent.num(keys.reduce(0) { $0 + (entry(h.id, $1)?.v ?? 0) })) \(h.unit))" : ""
            return "\(h.name) \(sk.filter { isDone(h, $0) }.count)/\(sk.count) days\(amount)"
        }.joined(separator: "; ")
        var awayBy: [String: Double] = [:]
        let ks = Set(keys)
        for x in away where x.skip != true && ks.contains(Fmt.key(epoch: x.s)) { awayBy[x.name, default: 0] += x.e - x.s }
        let awayT = awayBy.sortedDesc.map { "\($0.key) \(Int($0.value / 60)) min" }.joined(separator: "; ")
        let bpT = S.bp.sortedDesc.map { "\($0.key) \(Int($0.value / 60)) min" }.joined(separator: "; ")
        var out = ""
        if !bpT.isEmpty { out += "Browser profiles/accounts: \(bpT).\n" }
        if !awayT.isEmpty { out += "Time away from the screen, as logged: \(awayT).\n" }
        if !hab.isEmpty { out += "Habits ticked off (done/scheduled days): \(hab).\n" }
        out += "Apps: \(top(S.a)).\nWebsites: \(top(S.d)).\nCategories: \(top(S.c)).\n"
        out += "Productive \(Int(S.productive / 60)) min, neutral \(Int(S.neutral / 60)) min, distracting \(Int(S.distracting / 60)) min. "
        out += "Focus score \(S.score.map(String.init) ?? "n/a")/100. Sessions \(S.n), app switches \(S.sw), longest stretch \(Int(S.L / 60)) min in \(S.La.isEmpty ? "n/a" : S.La)."
        return out
    }

    var deviceText: String { dev == .all ? "Mac + iPhone" : dev.label }

    func overviewPrompt(_ d: OverviewData) -> String {
        let S = d.S
        let per = period == .day
            ? S.h.enumerated().map { "\($0)h \(Int($1 / 60))m" }.joined(separator: ", ")
            : d.days.map { "\($0.k): \(Int($0.pick(dev).t / 60)) min" }.joined(separator: ", ")
        return """
        You are a candid, kind analyst of someone's own screen-time data. Period: \(period.rawValue) "\(d.range.label)" (\(deviceText)). Total \(Int(S.t / 60)) min.
        \(aiBase(S, keys: d.range.keys))
        \(period == .day ? "Minutes per hour" : "Minutes per day"): \(per).
        Write one short paragraph (3-4 sentences) on how the time was spent, then 3 lines starting with "• " on notable patterns, then 2 lines starting with "→ " with specific, practical suggestions. Use the real numbers. Plain text, under 170 words.
        """
    }

    func runAI(key: String, prompt: String) async {
        guard settings.privacy.ai else {
            aiTexts[key] = "AI summaries are switched off in Settings › Privacy, so nothing is sent to Claude."
            return
        }
        aiRunning.insert(key)
        aiTexts[key] = "Thinking…"
        defer { aiRunning.remove(key) }
        do {
            let text = try await AIService.write(prompt: prompt, model: settings.aiModel ?? AIService.defaultModel) { [weak self] t in
                self?.aiTexts[key] = t
            }
            aiTexts[key] = text
            Storage.write("ai.json", aiTexts)
        } catch {
            aiTexts[key] = error.localizedDescription
        }
    }
}

struct AISummaryCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var title: String
    var key: String
    var button: String
    var placeholder: String
    var prompt: () -> String

    var body: some View {
        let text = model.aiTexts[key]
        Card {
            CardHeader(title: title) {
                Button(text == nil ? button : "Rewrite") {
                    let p = prompt()
                    Task { await model.runAI(key: key, prompt: p) }
                }
                .spentButton(.primary)
                .disabled(model.aiRunning.contains(key))
            }
            Text(text ?? placeholder)
                .font(.system(size: 14))
                .foregroundStyle(text == nil ? skin.muted : skin.ink)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
