import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?

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
        popover.behavior = .transient
        popover.animates = true

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true { self?.closePopover() }
        }
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
        popover.contentSize = NSSize(width: 440, height: 360)
        popover.contentViewController = NSHostingController(
            rootView: JournalEntryView(
                onClose: { [weak self] in self?.closePopover() },
                onOpenSettings: { [weak self] in self?.openSettings() }
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
