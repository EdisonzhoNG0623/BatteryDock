import AppKit
import BatteryDockCore
import Foundation

@MainActor
final class BatteryDockApplication: NSObject, NSApplicationDelegate {
    private let probe = SystemBatteryProbe()
    private let controller = CruiseController()
    private let backend: any ChargeControlling =
        ExternalBattChargeBackend.detect() ?? MonitorOnlyChargeBackend()
    private let settingsStore = SettingsStore()

    private var policy = ChargePolicy()
    private var topUpOriginalPolicy: ChargePolicy?
    private var previousPhase: CruisePhase?
    private var statusItem: NSStatusItem!
    private var statusLine = NSMenuItem(title: "正在读取电池…", action: nil, keyEquivalent: "")
    private var policyLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var healthLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var backendLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var cruiseItem = NSMenuItem(title: "巡航模式", action: #selector(toggleCruiseMode), keyEquivalent: "")
    private var topUpItem = NSMenuItem(title: "一次性充到 100%", action: #selector(toggleTopUp), keyEquivalent: "")
    private var timer: Timer?

    static func main() {
        let app = NSApplication.shared
        let delegate = BatteryDockApplication()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        policy = settingsStore.load()
        topUpOriginalPolicy = settingsStore.loadTopUpOriginalPolicy()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🔋 …"
        statusItem.button?.toolTip = "BatteryDock"
        statusItem.menu = buildMenu()
        synchronizeBackend()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "BatteryDock")
        for item in [statusLine, policyLine, healthLine, backendLine] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let limitMenu = NSMenu(title: "充电上限")
        for limit in [60, 70, 75, 80, 85, 90, 100] {
            let title = limit == 100 ? "100%（充满，需手动恢复）" : "\(limit)%"
            let item = NSMenuItem(
                title: title,
                action: #selector(selectUpperLimit(_:)),
                keyEquivalent: ""
            )
            item.tag = limit
            item.target = self
            limitMenu.addItem(item)
        }
        let limitRoot = NSMenuItem(title: "充电上限", action: nil, keyEquivalent: "")
        limitRoot.submenu = limitMenu
        menu.addItem(limitRoot)

        cruiseItem.target = self
        menu.addItem(cruiseItem)

        topUpItem.target = self
        menu.addItem(topUpItem)

        let rangeMenu = NSMenu(title: "巡航区间")
        for delta in [3, 5, 10, 15] {
            let item = NSMenuItem(
                title: "\(delta)%",
                action: #selector(selectCruiseDelta(_:)),
                keyEquivalent: ""
            )
            item.tag = delta
            item.target = self
            rangeMenu.addItem(item)
        }
        let rangeRoot = NSMenuItem(title: "巡航区间", action: nil, keyEquivalent: "")
        rangeRoot.submenu = rangeMenu
        menu.addItem(rangeRoot)

        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let quitItem = NSMenuItem(title: "退出 BatteryDock", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        updateMenuChecks()
        return menu
    }

    @objc private func selectUpperLimit(_ sender: NSMenuItem) {
        cancelTopUpIfNeeded()
        policy.upperLimit = sender.tag
        persistAndRefresh()
    }

    @objc private func selectCruiseDelta(_ sender: NSMenuItem) {
        cancelTopUpIfNeeded()
        policy.cruiseDelta = sender.tag
        persistAndRefresh()
    }

    @objc private func toggleCruiseMode() {
        policy.cruiseModeEnabled.toggle()
        previousPhase = nil
        persistAndRefresh()
    }

    @objc private func toggleTopUp() {
        if topUpOriginalPolicy != nil {
            finishTopUp()
        } else {
            guard policy.upperLimit < 100 else { return }
            topUpOriginalPolicy = policy
            settingsStore.saveTopUpOriginalPolicy(policy)
            previousPhase = nil
            synchronizeBackend()
        }
        updateMenuChecks()
        refresh()
    }

    private func cancelTopUpIfNeeded() {
        guard topUpOriginalPolicy != nil else { return }
        topUpOriginalPolicy = nil
        settingsStore.saveTopUpOriginalPolicy(nil)
        previousPhase = nil
    }

    private func finishTopUp() {
        guard let originalPolicy = topUpOriginalPolicy else { return }
        policy = originalPolicy
        settingsStore.save(originalPolicy)
        topUpOriginalPolicy = nil
        settingsStore.saveTopUpOriginalPolicy(nil)
        previousPhase = nil
        synchronizeBackend()
    }

    private var effectivePolicy: ChargePolicy {
        guard topUpOriginalPolicy != nil else { return policy }
        return ChargePolicy(upperLimit: 100, cruiseModeEnabled: false, cruiseDelta: policy.cruiseDelta)
    }

    private func persistAndRefresh() {
        settingsStore.save(policy)
        updateMenuChecks()
        synchronizeBackend()
        refresh()
    }

    private func synchronizeBackend() {
        guard backend.isAvailable else { return }
        do {
            try backend.synchronize(policy: effectivePolicy)
            backendLine.title = "控制后端：\(backend.displayName)"
        } catch {
            backendLine.title = "控制失败：\(error.localizedDescription)"
        }
    }

    private func updateMenuChecks() {
        cruiseItem.state = policy.cruiseModeEnabled ? .on : .off
        cruiseItem.isEnabled = topUpOriginalPolicy == nil
        topUpItem.title = topUpOriginalPolicy == nil
            ? "一次性充到 100%"
            : "取消一次性充满并恢复 \(policy.upperLimit)%"
        topUpItem.state = topUpOriginalPolicy == nil ? .off : .on
        topUpItem.isEnabled = topUpOriginalPolicy != nil || policy.upperLimit < 100
        guard let menu = statusItem?.menu else { return }
        for root in menu.items {
            guard let submenu = root.submenu else { continue }
            if root.title == "充电上限" {
                submenu.items.forEach { $0.state = $0.tag == policy.upperLimit ? .on : .off }
            } else if root.title == "巡航区间" {
                submenu.items.forEach { $0.state = $0.tag == policy.cruiseDelta ? .on : .off }
            }
        }
    }

    @objc private func refresh() {
        do {
            let snapshot = try probe.read()
            if topUpOriginalPolicy != nil, snapshot.percentage >= 100 {
                finishTopUp()
                updateMenuChecks()
            }
            let decision = controller.decide(
                snapshot: snapshot,
                policy: effectivePolicy,
                previousPhase: previousPhase
            )
            previousPhase = decision.phase

            statusItem.button?.title = "🔋 \(snapshot.percentage)%"
            let source = snapshot.isConnectedToPower ? "电源" : "电池"
            let charging = snapshot.isCharging ? "，正在充电" : ""
            statusLine.title = "电量 \(snapshot.percentage)% · \(source)\(charging)"
            if let original = topUpOriginalPolicy {
                policyLine.title = "一次性充满中 · 完成后恢复 \(original.lowerLimit)%–\(original.upperLimit)%"
            } else {
                policyLine.title = decision.explanation
            }

            let temperature = snapshot.temperatureCelsius.map { String(format: "%.1f°C", $0) } ?? "未知"
            let cycles = snapshot.cycleCount.map(String.init) ?? "未知"
            let health = snapshot.maximumCapacityPercent.map { "\($0)%" } ?? "未知"
            healthLine.title = "温度 \(temperature) · 循环 \(cycles) · 健康度 \(health)"
            if backendLine.title.isEmpty || !backendLine.title.hasPrefix("控制失败") {
                backendLine.title = "控制后端：\(backend.displayName)"
            }
        } catch {
            statusItem.button?.title = "🔋 !"
            statusLine.title = "读取失败：\(error.localizedDescription)"
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

BatteryDockApplication.main()
