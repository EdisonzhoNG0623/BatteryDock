# Changelog

This file describes changes that matter to people using BatteryDock. Dates use
the `YYYY-MM-DD` format.

## 1.0.0 — 2026-07-29

BatteryDock 1.0.0 is the first public stable release. It is a small macOS
menu-bar app for people who keep an Apple Silicon MacBook connected to power
and want a clearer charging policy.

### What you can do

- Set a charging ceiling between 60% and 100%. The default is 80%.
- Enable Cruise Mode to keep the battery inside a range instead of repeatedly
  topping it up by one percent. With the default settings, charging resumes at
  75% and pauses at 80%.
- Choose **One-shot charge to 100%** before travel or a long day away from a
  charger. BatteryDock remembers your previous settings and restores them
  automatically when the battery reaches 100%.
- See battery percentage, power source, charging state, temperature, cycle
  count, and estimated maximum capacity directly from the menu.
- Keep your selected limit, cruise range, and one-shot session after relaunching
  the app.

### Charging control and safety

- BatteryDock starts safely in monitor-only mode when no supported charging
  service is installed.
- Charging control can use a separately installed open-source `batt` daemon.
  BatteryDock never bundles `batt`, runs `sudo`, or stores an administrator
  password.
- Cruise Mode never deliberately drains the battery. It only decides when
  charging should pause or resume.

### Installation notes

- The release is built for Apple Silicon and requires macOS 13 or newer.
- The app is ad-hoc signed, not notarized by Apple. macOS may require a one-time
  confirmation in **System Settings → Privacy & Security** on first launch.
- Verify downloaded files with the included `SHA256SUMS.txt` before installing.

### Known limitations

- Without a compatible charging-control service, BatteryDock can monitor the
  battery and save preferences but cannot physically stop charging.
- Guided installation of a control service, automatic launch at login, thermal
  protection, schedules, and history charts are planned for later releases.
