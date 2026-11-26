import Foundation
import Security

/// Writes AI summaries with Claude via the Messages API (streamed over SSE). Only the
/// totals on screen are sent — never raw history. The API key lives in the macOS Keychain.
enum AIService {
    static let defaultModel = "claude-haiku-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    enum AIError: LocalizedError {
        case noKey, http(Int, String), refused, empty
        var errorDescription: String? {
            switch self {
            case .noKey: return "Add your Anthropic API key in Settings › Privacy to write summaries."
            case .http(429, _): return "Claude is busy, try again in a minute."
            case .http(401, _): return "The API key was rejected. Check it in Settings › Privacy."
            case .http(let c, let m): return "Couldn’t write a summary (\(c)): \(m)"
            case .refused: return "Claude declined to write this summary. Try again later."
            case .empty: return "Claude returned an empty summary."
            }
        }
    }

    /// Streams the answer, calling `onText` with the full text so far.
    static func write(prompt: String, model: String = defaultModel, onText: @escaping @MainActor (String) -> Void) async throws -> String {
        guard let key = Keychain.apiKey ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
            throw AIError.noKey
        }
        var req = URLRequest(url: endpoint, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 64000,
            "stream": true,
            "output_config": ["effort": "low"],
            "messages": [["role": "user", "content": prompt]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            let msg = ((try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }?["message"] as? String ?? raw
            throw AIError.http(status, String(msg.prefix(200)))
        }

        var blocks: [Int: String] = [:]   // text per content block index
        var stopReason = ""
        func joined() -> String { blocks.keys.sorted().compactMap { blocks[$0] }.joined() }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any],
                  let type = obj["type"] as? String else { continue }
            switch type {
            case "content_block_delta":
                if let i = obj["index"] as? Int, let delta = obj["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta", let t = delta["text"] as? String {
                    blocks[i, default: ""] += t
                    let text = joined()
                    await onText(text)
                }
            case "message_delta":
                if let d = obj["delta"] as? [String: Any], let r = d["stop_reason"] as? String { stopReason = r }
            case "error":
                let msg = (obj["error"] as? [String: Any])?["message"] as? String ?? "stream error"
                throw AIError.http(500, msg)
            default:
                break
            }
        }
        // Check the stop reason before trusting the text: a refusal's partial output is discarded.
        if stopReason == "refusal" { throw AIError.refused }
        let text = joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw AIError.empty }
        return text
    }
}

/// The Anthropic API key, stored as a generic password in the login keychain.
enum Keychain {
    private static let service = "com.spent.app"
    private static let account = "anthropic-api-key"

    static var apiKey: String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static var hasKey: Bool { apiKey?.isEmpty == false }

    @discardableResult
    static func setAPIKey(_ key: String?) -> Bool {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        guard let key, !key.isEmpty else { return true }
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
