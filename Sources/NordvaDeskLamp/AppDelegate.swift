import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    enum Mode {
        case normal
        case check
        case snapshot(String)
    }

    private static let openPanelPoll: TimeInterval = 1
    private static let backgroundPoll: TimeInterval = 10

    private var closedPanelPoll: TimeInterval? {
        lamp.backgroundUpdates ? Self.backgroundPoll : nil
    }

    private let mode: Mode
    private let lamp = Lamp()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var iconUpdates: AnyCancellable?

    init(mode: Mode) {
        self.mode = mode
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        switch mode {
        case .check:
            lamp.refresh { [lamp] in
                switch lamp.status {
                case .online:
                    print("lamp: \(lamp.isOn ? "on" : "off"), brightness \(Int(lamp.brightness))%, \(Int(lamp.temperature))K")
                case let .failed(message):
                    print("lamp: FAILED - \(message)")
                default:
                    print("lamp: no answer")
                }
                NSApp.terminate(nil)
            }
        case let .snapshot(path):
            lamp.refresh { [self] in
                renderPanel(to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
            }
        case .normal:
            setUpStatusItem()
            lamp.refresh()
            lamp.poll(every: closedPanelPoll)
        }
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item

        iconUpdates = lamp.$isOn.removeDuplicates().sink { [weak item] isOn in
            item?.button?.image = NSImage(
                systemSymbolName: isOn ? "lamp.desk.fill" : "lamp.desk",
                accessibilityDescription: isOn ? "Desk lamp on" : "Desk lamp off"
            )
        }

        popover.behavior = .transient
        popover.delegate = self
        // Without this the popover keeps the size the panel had when it was created and
        // clips the panel once its content grows (status text, settings section).
        let host = NSHostingController(rootView: panel)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
    }

    private var panel: LampPanel {
        LampPanel(lamp: lamp, quit: { NSApp.terminate(nil) })
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            lamp.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        Log.debug("panel opened")
        lamp.poll(every: Self.openPanelPoll)
    }

    func popoverDidClose(_ notification: Notification) {
        Log.debug("panel closed, background polling \(closedPanelPoll.map { "every \(Int($0)) s" } ?? "off")")
        lamp.poll(every: closedPanelPoll)
    }

    /// `--panel-snapshot <path>`: renders the panel to a PNG without showing it.
    private func renderPanel(to url: URL) {
        // The popover supplies the background on screen; a bare render would be transparent.
        let view = NSHostingView(rootView: panel.background(Color(nsColor: .windowBackgroundColor)))
        view.frame.size = view.fittingSize
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
