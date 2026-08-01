import AppKit

// A menu-bar-only app that manages a `caffeinate` child process.
//
// The child is always spawned with `-w <our pid>`, so macOS tears the power
// assertion down automatically if this app crashes or is force-quit. The app's
// own timer owns expiry (rather than `caffeinate -t`) so the countdown shown in
// the menu and the real assertion can never drift apart.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Presets

    private static let presets: [(title: String, hours: Double)] = [
        ("One Shot · 6 hours", 6),
        ("Double Shot · 10 hours", 10),
    ]

    // Built once. A menu bar app has no business re-decoding an image every
    // time it redraws.
    private static let idleImage = symbol("mug", fallback: "cup.and.saucer", label: "Coffee Shot: decaf")
    private static let activeImage = symbol("mug.fill", fallback: "cup.and.saucer.fill", label: "Coffee Shot: buzzing")

    private static func symbol(_ name: String, fallback: String, label: String) -> NSImage? {
        // `mug` is macOS 14+; fall back to the cup glyph on older systems.
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: label)
        image?.isTemplate = true
        return image
    }

    // MARK: - State

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private var caffeinate: Process?
    private var expiry: Date?
    private var activeHours: Double?

    // Fires once, at expiry. A repeating one-second timer would wake the CPU
    // 36,000 times over a double shot to redraw an icon that hasn't changed.
    private var expiryTimer: Timer?
    // One second, and only while the menu is actually open, so the countdown
    // animates without costing anything the rest of the time.
    private var menuTimer: Timer?

    private var keepDisplayOn: Bool {
        get { UserDefaults.standard.object(forKey: "keepDisplayOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "keepDisplayOn") }
    }

    private var isActive: Bool { caffeinate?.isRunning == true }

    // MARK: - Menu items

    private let headerItem = NSMenuItem(title: "Decaf", action: nil, keyEquivalent: "")
    private var presetItems: [NSMenuItem] = []
    private let turnOffItem = NSMenuItem(title: "Cut Me Off", action: nil, keyEquivalent: "")
    private let displayItem = NSMenuItem(title: "Screen Stays Lit", action: nil, keyEquivalent: "")

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy would put a second mug in the menu bar with no way to
        // tell them apart, so defer to the one already running.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != .current }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.setAccessibilityLabel("Coffee Shot")
        buildMenu()
        statusItem.menu = menu
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stop()
    }

    private func buildMenu() {
        menu.delegate = self

        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        presetItems = Self.presets.enumerated().map { index, preset in
            let item = NSMenuItem(title: preset.title, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            menu.addItem(item)
            return item
        }

        turnOffItem.action = #selector(cutOff)
        turnOffItem.target = self
        menu.addItem(turnOffItem)

        menu.addItem(.separator())

        displayItem.action = #selector(toggleDisplay)
        displayItem.target = self
        menu.addItem(displayItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Coffee Shot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Menu delegate

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        guard isActive else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        menuTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = nil
    }

    // MARK: - Actions

    @objc private func selectPreset(_ sender: NSMenuItem) {
        let preset = Self.presets[sender.tag]
        // Ordering the shot you're already on cuts you off, so the menu doubles
        // as an on/off toggle without a separate mode.
        if isActive, activeHours == preset.hours {
            stop()
        } else {
            start(seconds: preset.hours * 3600, preset: preset.hours)
        }
        refresh()
    }

    @objc private func cutOff() {
        stop()
        refresh()
    }

    @objc private func toggleDisplay() {
        keepDisplayOn.toggle()
        // Respawn with the new flags, keeping whatever time is left on the clock.
        if isActive, let expiry {
            start(seconds: max(expiry.timeIntervalSinceNow, 1), preset: activeHours)
        }
        refresh()
    }

    // MARK: - caffeinate control

    private func start(seconds: TimeInterval, preset: Double?) {
        stop()

        var args = ["-i", "-m"]                 // no idle sleep, no disk idle
        if keepDisplayOn { args.append("-d") }  // and optionally no display sleep
        args += ["-w", String(ProcessInfo.processInfo.processIdentifier)]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = args
        process.terminationHandler = { _ in
            Task { @MainActor [weak self] in self?.caffeinateDidExit() }
        }

        do {
            try process.run()
        } catch {
            NSLog("Coffee Shot: failed to launch caffeinate — \(error)")
            clearState()
            return
        }

        caffeinate = process
        activeHours = preset
        let deadline = Date().addingTimeInterval(seconds)
        expiry = deadline

        // Scheduled against a wall-clock date, so sleeping through the deadline
        // still ends the session on the next wake.
        let timer = Timer(fire: deadline, interval: 0, repeats: false) { _ in
            Task { @MainActor [weak self] in
                self?.stop()
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func stop() {
        if let process = caffeinate, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
        }
        clearState()
    }

    private func clearState() {
        caffeinate = nil
        expiry = nil
        activeHours = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    /// caffeinate died without us asking — killed externally, or it failed.
    private func caffeinateDidExit() {
        guard caffeinate?.isRunning != true else { return }
        clearState()
        refresh()
    }

    // MARK: - Rendering

    private func refresh() {
        let active = isActive

        statusItem.button?.image = active ? Self.activeImage : Self.idleImage
        statusItem.button?.toolTip = active ? "Buzzing — \(remainingText()) left" : "Coffee Shot — decaf"

        headerItem.title = active ? "Buzzing — \(remainingText()) left" : "Decaf"

        for (index, item) in presetItems.enumerated() {
            item.state = (active && activeHours == Self.presets[index].hours) ? .on : .off
        }

        turnOffItem.isHidden = !active
        displayItem.state = keepDisplayOn ? .on : .off
    }

    private func remainingText() -> String {
        guard let expiry else { return "0:00:00" }
        let total = max(0, Int(expiry.timeIntervalSinceNow.rounded()))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
