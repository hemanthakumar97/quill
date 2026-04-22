import SwiftUI

private enum OllamaFetch {
    case idle, loading, loaded([ModelOption]), failed(String)
}

struct SettingsView: View {
    var onClose: () -> Void

    @ObservedObject private var cfg = ConfigManager.shared
    @State private var draftKeys: [String: String] = [:]
    @State private var showKey = false
    @State private var ollamaFetch: OllamaFetch = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary).font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    Toggle("Enable AI polishing", isOn: $cfg.config.aiEnabled)
                        .toggleStyle(.switch)

                    if cfg.config.aiEnabled {

                        // Provider
                        section("Provider") {
                            Picker("", selection: $cfg.config.provider) {
                                ForEach(AIProvider.allCases, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: cfg.config.provider) {
                                ollamaFetch = .idle
                            }
                        }

                        // API Key / Ollama host
                        if cfg.config.provider.requiresAPIKey {
                            section("API Key") {
                                HStack {
                                    if showKey {
                                        TextField("Paste key here...", text: draftKeyBinding)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        SecureField("Paste key here...", text: draftKeyBinding)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    Button { showKey.toggle() } label: {
                                        Image(systemName: showKey ? "eye.slash" : "eye")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text(keyHint).font(.caption).foregroundColor(.secondary)
                            }
                        } else {
                            section("Ollama Host") {
                                TextField("http://localhost:11434", text: $cfg.config.ollamaHost)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: cfg.config.ollamaHost) { ollamaFetch = .idle }
                                Text("Run `ollama list` in Terminal to see installed models.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }

                        // Model picker
                        section("Model") {
                            modelSection
                        }

                        // Polish Mode
                        section("Polish Mode") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(PolishMode.allCases, id: \.self) { mode in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: cfg.config.mode == mode
                                              ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(cfg.config.mode == mode ? .accentColor : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(mode.displayName).font(.body)
                                            Text(mode.detail).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { cfg.config.mode = mode }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { saveAndClose() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
        }
        .frame(width: 440, height: 480)
        .onAppear {
            for p in AIProvider.allCases { draftKeys[p.rawValue] = cfg.config.apiKey(for: p) }
        }
    }

    // MARK: Model section

    @ViewBuilder
    private var modelSection: some View {
        let provider = cfg.config.provider

        if provider == .ollama {
            ollamaModelSection
        } else {
            let models = provider.curatedModels
            Picker("", selection: curatedModelBinding(models: models)) {
                ForEach(models) { m in
                    HStack {
                        Text(m.label)
                        Text("· \(m.tier)")
                            .foregroundColor(.secondary)
                    }
                    .tag(m.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onAppear {
                if cfg.config.selectedModel(for: provider).isEmpty {
                    cfg.config.setSelectedModel(provider.defaultModelID, for: provider)
                }
            }
        }
    }

    @ViewBuilder
    private var ollamaModelSection: some View {
        switch ollamaFetch {
        case .idle:
            Button("Load installed models") { fetchOllamaModels() }
                .buttonStyle(.bordered)

        case .loading:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Loading…").foregroundColor(.secondary)
            }

        case .loaded(let models):
            HStack {
                if models.isEmpty {
                    Text("No models found. Run `ollama pull llama3` to install one.")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Picker("", selection: ollamaModelBinding(models: models)) {
                        ForEach(models) { m in Text(m.label).tag(m.id) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Button { fetchOllamaModels() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

        case .failed(let err):
            VStack(alignment: .leading, spacing: 6) {
                Text(err).font(.caption).foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { fetchOllamaModels() }.buttonStyle(.bordered)
            }
        }
    }

    // MARK: Helpers

    private func fetchOllamaModels() {
        let host = cfg.config.ollamaHost
        ollamaFetch = .loading
        Task {
            do {
                let models = try await AIManager.shared.fetchOllamaModels(host: host)
                await MainActor.run {
                    ollamaFetch = .loaded(models)
                    if cfg.config.selectedModel(for: .ollama).isEmpty, let first = models.first {
                        cfg.config.setSelectedModel(first.id, for: .ollama)
                    }
                }
            } catch {
                await MainActor.run { ollamaFetch = .failed(error.localizedDescription) }
            }
        }
    }

    private func curatedModelBinding(models: [ModelOption]) -> Binding<String> {
        Binding(
            get: {
                let saved = cfg.config.selectedModel(for: cfg.config.provider)
                return models.contains(where: { $0.id == saved }) ? saved : (models.first?.id ?? "")
            },
            set: { cfg.config.setSelectedModel($0, for: cfg.config.provider) }
        )
    }

    private func ollamaModelBinding(models: [ModelOption]) -> Binding<String> {
        Binding(
            get: {
                let saved = cfg.config.selectedModel(for: .ollama)
                return models.contains(where: { $0.id == saved }) ? saved : (models.first?.id ?? "")
            },
            set: { cfg.config.setSelectedModel($0, for: .ollama) }
        )
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).fontWeight(.medium)
            content()
        }
    }

    private var draftKeyBinding: Binding<String> {
        Binding(
            get: { draftKeys[cfg.config.provider.rawValue] ?? "" },
            set: { draftKeys[cfg.config.provider.rawValue] = $0 }
        )
    }

    private var keyHint: String {
        switch cfg.config.provider {
        case .claude:  return "console.anthropic.com → API Keys"
        case .openai:  return "platform.openai.com → API Keys"
        case .gemini:  return "aistudio.google.com → Get API Key"
        case .ollama:  return ""
        }
    }

    private func saveAndClose() {
        for p in AIProvider.allCases { cfg.config.setApiKey(draftKeys[p.rawValue] ?? "", for: p) }
        cfg.save()
        onClose()
    }
}
