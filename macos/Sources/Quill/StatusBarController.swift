import AppKit
import SwiftUI

/// Shared mutable state between JournalEntryView and StatusBarController.
/// Reference type so both sides see live values without bindings.
final class EntryCoordinator {
    var isPolishing = false
    var pendingText = ""
}

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private var entryCoordinator = EntryCoordinator()

    init() {
        DispatchQueue.main.async { self.setup() }
    }

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "book.pages", accessibilityDescription: "Quill")
            button.image?.isTemplate = true
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.handleExternalDismiss()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleExternalDismiss()
        }
    }

    private func handleExternalDismiss() {
        guard popover.isShown else { return }
        if entryCoordinator.isPolishing { return }
        let text = entryCoordinator.pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { try? JournalManager().appendEntry(text) }
        closePopover()
    }

    // MARK: Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleJournal()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Quill", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: Journal

    private func toggleJournal() {
        if popover.isShown {
            closePopover()
        } else {
            openJournal()
        }
    }

    private func openJournal() {
        entryCoordinator = EntryCoordinator()
        popover.contentSize = NSSize(width: 440, height: 360)
        popover.contentViewController = NSHostingController(
            rootView: JournalEntryView(
                onClose: { [weak self] in self?.closePopover() },
                onOpenSettings: { [weak self] in self?.openSettings() },
                coordinator: entryCoordinator
            )
        )
        showPopover()
    }

    // MARK: Settings

    @objc func openSettings() {
        if popover.isShown { closePopover() }
        popover.contentSize = NSSize(width: 440, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(onClose: { [weak self] in self?.closePopover() })
        )
        showPopover()
    }

    // MARK: Popover lifecycle

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        eventMonitor?.start()
    }

    private func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }
}

// MARK: EventMonitor

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    deinit { stop() }
}
