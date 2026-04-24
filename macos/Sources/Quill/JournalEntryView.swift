import SwiftUI

private enum EntryState {
    case writing
    case polishing
    case preview(polished: String)
    case saved
    case error(String)
}

struct JournalEntryView: View {
    var onClose: () -> Void
    var onOpenSettings: () -> Void
    var coordinator: EntryCoordinator = .init()

    @State private var entryText = ""
    @State private var state: EntryState = .writing
    @FocusState private var editorFocused: Bool
    
    @StateObject private var voiceManager = VoiceManager()

    @ObservedObject private var cfg = ConfigManager.shared
    private let journal = JournalManager()

    var body: some View {
        ZStack {
            switch state {
            case .writing:
                writingView
            case .polishing:
                polishingView
            case .preview(let polished):
                previewView(polished: polished)
            case .saved:
                savedView
            case .error(let msg):
                errorView(msg)
            }
        }
        .frame(width: 440, height: 360)
        .animation(.easeInOut(duration: 0.2), value: stateID)
        .onAppear {
            entryText = ""
            coordinator.pendingText = ""
            coordinator.isPolishing = false
            state = .writing
            editorFocused = true
        }
        .onChange(of: entryText) { _, newText in
            coordinator.pendingText = newText
        }
        .onChange(of: stateID) { _, id in
            coordinator.isPolishing = (id == 1)
        }
    }

    // MARK: Writing

    private var writingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(journal.todayDisplayString())
                    .font(.headline)
                Spacer()
                if cfg.config.aiEnabled {
                    providerBadge
                }
                Button { onOpenSettings() } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(
                    get: {
                        if voiceManager.isListening && !voiceManager.partialText.isEmpty {
                            return entryText + (entryText.isEmpty ? "" : " ") + voiceManager.partialText
                        }
                        return entryText
                    },
                    set: { entryText = $0 }
                ))
                .font(.body)
                .lineSpacing(4)
                .frame(minHeight: 250)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(placeholder, alignment: .topLeading)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) { return .ignored }
                    handleSave()
                    return .handled
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            toggleVoice()
                        } label: {
                            Image(systemName: voiceManager.isListening ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(voiceManager.isListening ? .red : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .help(voiceManager.isListening ? "Stop listening" : "Voice input")
                    }
                }
            }

            HStack {
                Text(cfg.config.aiEnabled ? "↵ polish & save  ·  ⇧↵ new line" : "↵ save  ·  ⇧↵ new line")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.6))
                Spacer()
                Button(cfg.config.aiEnabled ? "Polish & Save" : "Save") { handleSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && voiceManager.partialText.isEmpty)
            }
        }
        .padding(16)
    }

    // MARK: Polishing

    private var polishingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Polishing your entry…")
                .font(.body)
                .foregroundColor(.secondary)
            Text("via \(cfg.config.provider.displayName)")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Preview

    private func previewView(polished: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("AI Preview")
                    .font(.headline)
                Spacer()
                Text(cfg.config.mode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
            }

            Divider()

            ScrollView {
                Text(polished)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .frame(minHeight: 220)

            HStack(spacing: 10) {
                Button("Save Original") {
                    commit(text: entryText)
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Save Polished") {
                    commit(text: polished)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
    }

    // MARK: Saved

    private var savedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("Saved")
                .font(.title2)
                .fontWeight(.semibold)
            Text(journal.savedToPath())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Error

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(msg)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Button("Save Original") {
                    commit(text: entryText)
                }
                .buttonStyle(.bordered)
                Button("Retry") {
                    Task { await runPolish() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Actions
    
    private func toggleVoice() {
        if voiceManager.isListening {
            voiceManager.stopListening()
        } else {
            voiceManager.startListening(onResults: { result in
                let trimmed = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
                entryText = trimmed.isEmpty ? result : "\(trimmed) \(result)"
            }, onError: { error in
                state = .error(error)
            })
        }
    }

    private func handleSave() {
        let currentText = voiceManager.isListening && !voiceManager.partialText.isEmpty 
            ? entryText + (entryText.isEmpty ? "" : " ") + voiceManager.partialText 
            : entryText
            
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if voiceManager.isListening {
            voiceManager.stopListening()
        }
        
        entryText = trimmed

        if cfg.config.aiEnabled {
            Task { await runPolish() }
        } else {
            commit(text: entryText)
        }
    }

    @MainActor
    private func runPolish() async {
        state = .polishing
        do {
            let polished = try await AIManager.shared.polish(entryText, config: cfg.config)
            state = .preview(polished: polished)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func commit(text: String) {
        do {
            try journal.appendEntry(text)
            coordinator.pendingText = ""
            state = .saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onClose() }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: Helpers

    private var placeholder: some View {
        Group {
            if entryText.isEmpty && voiceManager.partialText.isEmpty {
                Text(voiceManager.isListening ? "Listening..." : "What's on your mind today?")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var providerBadge: some View {
        Text(cfg.config.provider.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(4)
    }

    private var stateID: Int {
        switch state {
        case .writing:   return 0
        case .polishing: return 1
        case .preview:   return 2
        case .saved:     return 3
        case .error:     return 4
        }
    }
}
