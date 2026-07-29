# BatteryDock

BatteryDock is an open-source macOS menu-bar battery manager for Apple Silicon
Macs. It provides an adjustable charging limit, a cruise range that avoids
micro-charging, and a one-shot full-charge action that automatically restores
the previous policy at 100%.

BatteryDock is independently implemented and is not affiliated with AlDente,
AppHouseKitchen, Apple, or the `batt` project.

## Features

- Native AppKit menu-bar interface
- Live battery level, power source, charging state, temperature, cycle count,
  and estimated maximum capacity
- Configurable charge target from 60% to 100%
- Cruise mode with configurable hysteresis (default: 75%–80%)
- One-shot charge to 100%, followed by automatic restoration of the previous
  limit and cruise range
- Persistent policy and one-shot session state across app relaunches
- Safe monitor-only operation when no supported control backend is installed
- Unit-tested charging policy state machine

## Requirements

- Apple Silicon MacBook
- macOS 13 or newer
- Xcode 26 or a compatible Swift 6 toolchain for building

Battery monitoring is read-only. On macOS versions without Apple's native
charge-limit API, actual charging control requires the separately installed
open-source [`batt`](https://github.com/charlie0129/batt) daemon. BatteryDock
does not bundle it, invoke `sudo`, or retain an administrator password.

## Install

Download `BatteryDock-1.0.0-macOS-arm64.dmg` from the
[latest release](https://github.com/EdisonzhoNG0623/BatteryDock/releases/latest),
open it, and drag **BatteryDock** into **Applications**. BatteryDock then appears
in Launchpad and runs from the menu bar rather than the Dock.

The 1.0.0 build is ad-hoc signed but not Apple-notarized. On first launch,
macOS may ask you to confirm it in **System Settings → Privacy & Security**.
Always verify the download against `SHA256SUMS.txt` from the same release.

## Build and run

```sh
swift test
swift run BatteryDock
```

To create a locally signed app bundle:

```sh
./scripts/build-app.sh
open dist/BatteryDock.app
```

To produce the same DMG, ZIP, and checksums used for a release:

```sh
./scripts/package-release.sh 1.0.0
```

The executable currently runs as an accessory/menu-bar process. Press `Control-C` in
the launching terminal to stop it if the menu-bar quit item is unavailable.

## Charging controls

- Choose an upper limit from the BatteryDock menu.
- Enable Cruise Mode and choose a delta. With an 80% upper limit and a 5%
  delta, charging resumes at 75% and pauses again at 80%.
- Choose **One-shot charge to 100%** to temporarily remove the limit. When the
  battery reaches 100%, BatteryDock restores the complete previous policy.
  Selecting the item again cancels the one-shot session immediately.

When using an external charging-control daemon, disable macOS Optimized Battery
Charging to avoid conflicting policies.

## Safety boundary

Battery monitoring is read-only. Charge control requires a separately installed,
signed privileged helper because Apple does not expose third-party charging control
through a public API on macOS 15. BatteryDock will remain monitor-only when that helper
is absent; it will never silently request or retain an administrator password.

## Roadmap

1. Guided installation and health checks for supported control backends
2. Thermal protection
3. Sleep/wake diagnostics and reconciliation
4. Schedules, calibration assistance, and history charts

### Optional control backend during development

When a separately installed `batt` executable and daemon are detected, BatteryDock
can synchronize the upper limit and cruise delta with that service. `batt` is GPL-2.0
software by its own contributors and is not bundled with BatteryDock. Without it,
BatteryDock intentionally stays read-only.

## License

BatteryDock is released under the [MIT License](LICENSE). See
[Third-party notices](THIRD_PARTY_NOTICES.md) for optional integrations.

User-visible changes are documented in [CHANGELOG.md](CHANGELOG.md).
