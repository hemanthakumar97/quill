import Foundation

final class JournalManager {
    private var vaultJournalPath: String { ConfigManager.shared.config.journalPath }

    func journalFilePath(for date: Date = Date()) -> URL {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM-yyyy"
        let fileName = "\(fmt.string(from: date)).md"
        return URL(fileURLWithPath: vaultJournalPath)
            .appendingPathComponent("\(year)", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    func todayDisplayString(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy"
        return fmt.string(from: date)
    }

    func savedToPath(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM-yyyy"
        return "Journal/\(Calendar.current.component(.year, from: date))/\(fmt.string(from: date)).md"
    }

    func currentTimeString(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }

    private func daySectionHeader(for date: Date) -> String {
        "## \(todayDisplayString(for: date))"
    }

    private func timeHeader(for date: Date) -> String {
        "### \(currentTimeString(for: date))"
    }

    func isVaultMounted() -> Bool {
        FileManager.default.fileExists(atPath: vaultJournalPath)
    }

    func appendEntry(_ text: String, date: Date = Date()) throws {
        guard isVaultMounted() else {
            throw JournalError.vaultNotMounted
        }

        let fileURL = journalFilePath(for: date)
        let dirURL = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: dirURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        var existing = ""
        if FileManager.default.fileExists(atPath: fileURL.path) {
            existing = try String(contentsOf: fileURL, encoding: .utf8)
        }

        let dayHeader = daySectionHeader(for: date)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeHdr = timeHeader(for: date)

        let block: String
        if existing.contains(dayHeader) {
            block = "\n\(timeHdr)\n\(trimmed)\n"
        } else {
            let separator = existing.isEmpty ? "" : "\n"
            block = "\(separator)\(dayHeader)\n\n\(timeHdr)\n\(trimmed)\n"
        }

        try (existing + block).write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

enum JournalError: LocalizedError {
    case vaultNotMounted

    var errorDescription: String? {
        switch self {
        case .vaultNotMounted:
            return "Obsidian Vault is not mounted. Please connect the drive and try again."
        }
    }
}
