import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    enum Mode {
        case normal
        case check
        case snapshot(String)
    }

    private let mode: Mode
    private let lamp = Lamp()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?

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
        }
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "lamp.desk", accessibilityDescription: "NordvaDeskLamp")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: panel)
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
