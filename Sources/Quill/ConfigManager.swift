import Foundation
import Combine

struct ModelOption: Identifiable, Hashable {
    let id: String       // API model ID sent in requests
    let label: String    // Display name shown in the picker
    let tier: String     // Flagship / Balanced / Fast
}

enum AIProvider: String, CaseIterable, Codable {
    case claude, openai, gemini, ollama

    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .openai:  return "ChatGPT"
        case .gemini:  return "Gemini"
        case .ollama:  return "Local (Ollama)"
        }
    }

    var requiresAPIKey: Bool { self != .ollama }

    // Curated list — only shown in each provider's chat UI
    var curatedModels: [ModelOption] {
        switch self {
        case .claude:
            return [
                ModelOption(id: "claude-opus-4-7",           label: "Opus 4.7",   tier: "Flagship"),
                ModelOption(id: "claude-sonnet-4-6",          label: "Sonnet 4.6", tier: "Balanced"),
                ModelOption(id: "claude-haiku-4-5-20251001",  label: "Haiku 4.5",  tier: "Fast"),
            ]
        case .openai:
            return [
                ModelOption(id: "gpt-5.4",      label: "GPT-5.4",       tier: "Flagship"),
                ModelOption(id: "gpt-5.4-mini", label: "GPT-5.4 mini",  tier: "Balanced"),
                ModelOption(id: "gpt-5.4-nano", label: "GPT-5.4 nano",  tier: "Fast"),
            ]
        case .gemini:
            return [
                ModelOption(id: "gemini-3.1-pro-preview",      label: "Gemini 3.1 Pro",       tier: "Flagship"),
                ModelOption(id: "gemini-3-flash-preview",      label: "Gemini 3 Flash",        tier: "Balanced"),
                ModelOption(id: "gemini-3.1-flash-lite-preview", label: "Gemini 3.1 Flash Lite", tier: "Fast"),
                ModelOption(id: "gemini-2.5-flash",            label: "Gemini 2.5 Flash",      tier: "Stable"),
            ]
        case .ollama:
            return []  // fetched dynamically
        }
    }

    var defaultModelID: String {
        curatedModels.first(where: { $0.tier == "Balanced" })?.id
            ?? curatedModels.first?.id
            ?? ""
    }
}

enum PolishMode: String, CaseIterable, Codable {
    case light, full, structured

    var displayName: String {
        switch self {
        case .light:      return "Light Polish"
        case .full:       return "Full Rewrite"
        case .structured: return "Structured"
        }
    }

    var detail: String {
        switch self {
        case .light:      return "Fix grammar, keep your voice"
        case .full:       return "Expand into flowing prose"
        case .structured: return "Organize into sections"
        }
    }

    var systemPrompt: String {
        switch self {
        case .light:
            return """
            You are a light copy-editor for a personal journal. \
            Fix grammar and spelling, improve readability, but preserve the author's exact voice, \
            tone, and meaning. Make minimal changes — do not add new ideas or expand the text. \
            Return only the polished journal text with no commentary or explanation.
            """
        case .full:
            return """
            You are a journaling assistant. Rewrite the following raw journal notes into \
            rich, flowing, reflective prose. Keep the meaning and emotions intact but make \
            it read like a thoughtful personal diary entry. \
            Return only the rewritten text with no commentary or explanation.
            """
        case .structured:
            return """
            You are a journaling assistant. Reorganize the following raw journal notes into \
            three clearly labeled sections using markdown bold: \
            **What happened**, **How I felt**, **Key takeaway**. \
            Be concise and faithful to the original content. \
            Return only the formatted text with no commentary or explanation.
            """
        }
    }
}

struct AppConfig: Codable {
    var provider: AIProvider  = .claude
    var mode: PolishMode      = .light
    var aiEnabled: Bool       = true
    var apiKeys: [String: String] = [:]
    var selectedModels: [String: String] = [:]
    var ollamaHost: String    = "http://localhost:11434"
    var journalPath: String   = "/Volumes/Hemanth/Obsidian Vault/Journal"

    func apiKey(for p: AIProvider) -> String { apiKeys[p.rawValue] ?? "" }
    mutating func setApiKey(_ key: String, for p: AIProvider) { apiKeys[p.rawValue] = key }

    func selectedModel(for p: AIProvider) -> String { selectedModels[p.rawValue] ?? "" }
    mutating func setSelectedModel(_ model: String, for p: AIProvider) { selectedModels[p.rawValue] = model }
}

final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var config: AppConfig

    private let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/Quill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/Quill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        } else {
            config = AppConfig()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }
}
