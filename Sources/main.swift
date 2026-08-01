import AppKit

// A menu-bar-only app that manages a `caffeinate` child process.
//
// The child is always spawned with `-w <our pid>`, so macOS tears the power
// assertion down automatically if this app crashes or is force-quit. The app's
// own timer owns expiry (rather than `caffeinate -t`) so the countdown shown in
// the menu and the real assertion can never drift apart.

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Presets

    private static let presets: [(title: String, hours: Double)] = [
        ("One Shot · 6 hours", 6),
        ("Double Shot · 10 hours", 10),
    ]

    // MARK: - State

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private var caffeinate: Process?
    private var expiry: Date?
    private var activeHours: Double?
    private var tick: Timer?

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        statusItem.menu = menu
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopCaffeinate()
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

        turnOffItem.action = #selector(turnOff)
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

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - Actions

    @objc private func selectPreset(_ sender: NSMenuItem) {
        let preset = Self.presets[sender.tag]
        // Ordering the shot you're already on cuts you off, so the menu doubles
        // as an on/off toggle without a separate mode.
        if isActive, activeHours == preset.hours {
            stopCaffeinate()
        } else {
            startCaffeinate(hours: preset.hours)
        }
        refresh()
    }

    @objc private func turnOff() {
        stopCaffeinate()
        refresh()
    }

    @objc private func toggleDisplay() {
        keepDisplayOn.toggle()
        // Respawn with the new flags, preserving whatever time is left.
        if isActive, let expiry {
            let remaining = expiry.timeIntervalSinceNow
            let hours = activeHours
            startCaffeinate(hours: max(remaining, 1) / 3600)
            activeHours = hours          // keep the preset's checkmark accurate
            self.expiry = Date().addingTimeInterval(max(remaining, 1))
        }
        refresh()
    }

    // MARK: - caffeinate control

    private func startCaffeinate(hours: Double) {
        stopCaffeinate()

        var args = ["-i", "-m"]                 // no idle sleep, no disk idle
        if keepDisplayOn { args.append("-d") }  // and optionally no display sleep
        args += ["-w", String(ProcessInfo.processInfo.processIdentifier)]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = args
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.caffeinate?.isRunning != true else { return }
                self.clearState()
                self.refresh()
            }
        }

        do {
            try process.run()
        } catch {
            NSLog("Coffee Shot: failed to launch caffeinate — \(error)")
            clearState()
            return
        }

        caffeinate = process
        activeHours = hours
        expiry = Date().addingTimeInterval(hours * 3600)

        tick?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.onTick() }
        // .common keeps the countdown ticking while the menu is open and tracking.
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
    }

    private func stopCaffeinate() {
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
        tick?.invalidate()
        tick = nil
    }

    private func onTick() {
        if let expiry, Date() >= expiry {
            stopCaffeinate()
        }
        refresh()
    }

    // MARK: - Rendering

    private func refresh() {
        let active = isActive

        let label = active ? "Buzzing" : "Decaf"
        // `mug` is macOS 14+; fall back to the cup glyph on older systems.
        let image = NSImage(systemSymbolName: active ? "mug.fill" : "mug", accessibilityDescription: label)
            ?? NSImage(systemSymbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: label)
        image?.isTemplate = true
        statusItem.button?.image = image
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
