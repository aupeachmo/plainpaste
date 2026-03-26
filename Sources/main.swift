import Cocoa

// ---------------------------------------------------------------------------
// PlainPaste – a tiny macOS menu-bar utility that automatically strips
// rich-text formatting from the clipboard so every paste is plain text.
// ---------------------------------------------------------------------------

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isEnabled = true
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private var enabledMenuItem: NSMenuItem!

    // MARK: – Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.toolTip = "PlainPaste – strips clipboard formatting"
        }

        updateIcon()
        buildMenu()
        startMonitoring()
    }

    // MARK: – Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        if isEnabled {
            // Template image: macOS draws it in the native menu-bar color
            // and adapts automatically to light / dark mode.
            if let img = NSImage(systemSymbolName: "scissors",
                                 accessibilityDescription: "PlainPaste – active") {
                img.isTemplate = true
                button.image = img
            }
        } else {
            // Draw a diagonal slash through the scissors to match the
            // macOS convention for "off" (mic.slash, bell.slash, etc.).
            if let base = NSImage(systemSymbolName: "scissors",
                                  accessibilityDescription: "PlainPaste – paused") {
                button.image = slashedImage(base)
            }
        }
    }

    /// Composites a horizontal slash over an SF Symbol and returns
    /// the result as a template image.
    private func slashedImage(_ symbol: NSImage) -> NSImage {
        let size = symbol.size
        let img = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)

            // Horizontal line through the vertical centre,
            // crossing the pivot point of the scissors.
            let path = NSBezierPath()
            let inset: CGFloat = size.width * 0.05
            let midY = size.height / 2
            path.move(to: NSPoint(x: inset, y: midY))
            path.line(to: NSPoint(x: size.width - inset, y: midY))
            path.lineWidth = size.height * 0.12
            path.lineCapStyle = .round
            NSColor.black.setStroke()
            path.stroke()

            return true
        }
        img.isTemplate = true
        return img
    }

    // MARK: – Menu

    private func buildMenu() {
        let menu = NSMenu()

        enabledMenuItem = NSMenuItem(title: "Strip Formatting: On",
                                     action: #selector(toggleEnabled),
                                     keyEquivalent: "")
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        menu.addItem(NSMenuItem.separator())

        let stripNow = NSMenuItem(title: "One-time strip",
                                  action: #selector(stripClipboardNow),
                                  keyEquivalent: "")
        stripNow.target = self
        menu.addItem(stripNow)

        menu.addItem(NSMenuItem.separator())

        let about = NSMenuItem(title: "About PlainPaste",
                               action: #selector(showAbout),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit PlainPaste",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: – Clipboard monitoring

    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(timeInterval: 0.2,
                                     target: self,
                                     selector: #selector(pollClipboard),
                                     userInfo: nil,
                                     repeats: true)
        RunLoop.current.add(timer!, forMode: .common)
    }

    @objc private func pollClipboard() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard isEnabled, count != lastChangeCount else { return }
        lastChangeCount = count

        let types = pb.types ?? []
        let hasRich  = types.contains(.rtf) || types.contains(.html) || types.contains(.rtfd)
        let hasPlain = types.contains(.string)

        guard hasRich, hasPlain,
              let plain = pb.string(forType: .string) else { return }

        // Small delay so we don't race the app that just wrote to the clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            pb.clearContents()
            pb.setString(plain, forType: .string)
            self?.lastChangeCount = pb.changeCount
        }
    }

    // MARK: – Actions

    @objc private func stripClipboardNow() {
        let pb = NSPasteboard.general
        guard let plain = pb.string(forType: .string) else { return }
        pb.clearContents()
        pb.setString(plain, forType: .string)
        lastChangeCount = pb.changeCount
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledMenuItem.title = isEnabled
            ? "Strip Formatting: On"
            : "Strip Formatting: Off"
        updateIcon()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "PlainPaste"
        alert.informativeText = """
            A tiny menu-bar utility that automatically strips \
            rich-text formatting from whatever you copy, so every \
            paste is plain text.

            https://github.com/aupeachmo/plainpaste
            Version \(appVersion)
            """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: – Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)        // menu-bar only — no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
