import Foundation

enum AIError: LocalizedError {
    case noAPIKey(AIProvider)
    case network(String)
    case apiError(String)
    case ollamaOffline

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let p):   return "No API key for \(p.displayName). Add one in Settings."
        case .network(let msg):  return "Network error: \(msg)"
        case .apiError(let msg): return msg
        case .ollamaOffline:     return "Ollama isn't running. Start it with: ollama serve"
        }
    }
}

final class AIManager {
    static let shared = AIManager()
    private init() {}

    // MARK: - Polish

    func polish(_ text: String, config: AppConfig) async throws -> String {
        let prompt = "\(config.mode.systemPrompt)\n\n---\n\(text)"
        switch config.provider {
        case .claude:  return try await claude(prompt, key: config.apiKey(for: .claude),  model: config.selectedModel(for: .claude))
        case .openai:  return try await openai(prompt, key: config.apiKey(for: .openai),  model: config.selectedModel(for: .openai))
        case .gemini:  return try await gemini(prompt, key: config.apiKey(for: .gemini),  model: config.selectedModel(for: .gemini))
        case .ollama:  return try await ollama(prompt, host: config.ollamaHost,            model: config.selectedModel(for: .ollama))
        }
    }

    // MARK: - Fetch available models (Ollama only — others use curated lists)

    func fetchOllamaModels(host: String) async throws -> [ModelOption] {
        guard let url = URL(string: "\(host)/api/tags") else { throw AIError.network("Invalid Ollama host") }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try parseJSON(data)
            guard let models = json["models"] as? [[String: Any]] else {
                throw AIError.apiError("Could not read Ollama models.")
            }
            return models
                .compactMap { $0["name"] as? String }
                .sorted()
                .map { ModelOption(id: $0, label: $0, tier: "") }
        } catch let e as URLError where e.code == .cannotConnectToHost || e.code == .timedOut {
            throw AIError.ollamaOffline
        }
    }

    // MARK: - API calls

    private func claude(_ prompt: String, key: String, model: String) async throws -> String {
        guard !key.isEmpty else { throw AIError.noAPIKey(.claude) }
        let resolvedModel = model.isEmpty ? AIProvider.claude.defaultModelID : model
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": resolvedModel,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try parseJSON(data)
        if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
            throw AIError.apiError("Claude: \(msg)")
        }
        guard let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String
        else { throw AIError.apiError("Claude returned an unexpected format.") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func openai(_ prompt: String, key: String, model: String) async throws -> String {
        guard !key.isEmpty else { throw AIError.noAPIKey(.openai) }
        let resolvedModel = model.isEmpty ? AIProvider.openai.defaultModelID : model
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": resolvedModel,
            "messages": [["role": "user", "content": prompt]]
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try parseJSON(data)
        if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
            throw AIError.apiError("OpenAI: \(msg)")
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let text = msg["content"] as? String
        else { throw AIError.apiError("OpenAI returned an unexpected format.") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func gemini(_ prompt: String, key: String, model: String) async throws -> String {
        guard !key.isEmpty else { throw AIError.noAPIKey(.gemini) }
        let resolvedModel = model.isEmpty ? AIProvider.gemini.defaultModelID : model
        // Preview models use the same generateContent endpoint
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(resolvedModel):generateContent?key=\(key)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [["text": prompt]]]]
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try parseJSON(data)
        if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
            throw AIError.apiError("Gemini: \(msg)")
        }
        guard let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { throw AIError.apiError("Gemini returned an unexpected format.") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ollama(_ prompt: String, host: String, model: String) async throws -> String {
        guard let url = URL(string: "\(host)/api/chat") else { throw AIError.network("Invalid Ollama host URL") }
        let resolvedModel = model.isEmpty ? "llama3:latest" : model
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": resolvedModel,
            "stream": false,
            "messages": [["role": "user", "content": prompt]]
        ])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try parseJSON(data)
            if let errMsg = json["error"] as? String { throw AIError.apiError("Ollama: \(errMsg)") }
            guard let msg = json["message"] as? [String: Any],
                  let text = msg["content"] as? String
            else { throw AIError.apiError("Ollama returned an unexpected format.") }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let e as URLError where e.code == .cannotConnectToHost || e.code == .networkConnectionLost {
            throw AIError.ollamaOffline
        }
    }

    // MARK: - Helpers

    private func parseJSON(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8) ?? "(unreadable)"
            throw AIError.apiError("Could not parse response: \(raw.prefix(200))")
        }
        return json
    }
}

