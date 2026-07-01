# DingDong Product Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DingDong easier to maintain and safer to ship by separating preferences, clipboard monitoring, onboarding, and release regression guidance from the remaining large controller code.

**Architecture:** Keep the visible product behavior stable while extracting small services from `StatusController`. Centralize user defaults behind `AppPreferences`, keep AppKit-specific polling in `ClipboardMonitoringService`, and document the manual release path in the repo.

**Tech Stack:** Swift, SwiftUI, AppKit, Swift Testing, local loopback HTTP.

---

### Task 1: Centralize Preferences

**Files:**
- Create: `Sources/DingDong/AppPreferences.swift`
- Modify: `Sources/DingDong/StatusController.swift`
- Modify: `Sources/DingDong/SoundPlayer.swift`
- Test: `Tests/DingDongTests/AppPreferencesTests.swift`

- [ ] Create `AppPreferences` with typed methods for language, panel preferences, clipboard monitoring, clipboard filter order, clipboard group order, and custom sound path.
- [ ] Inject `AppPreferences` into `StatusController` and `SoundPlayer`.
- [ ] Replace direct `UserDefaults.standard` access in controller and sound player code.
- [ ] Add tests using an isolated `UserDefaults(suiteName:)`.
- [ ] Run `swift test`.

### Task 2: Extract Clipboard Monitoring

**Files:**
- Create: `Sources/DingDong/ClipboardMonitoringService.swift`
- Modify: `Sources/DingDong/StatusController.swift`
- Test: `Tests/DingDongTests/StatusControllerTests.swift`

- [ ] Move timer ownership, pasteboard change-count tracking, and start/stop behavior into `ClipboardMonitoringService`.
- [ ] Keep the capture callback in `StatusController` so resource mutation stays in one place.
- [ ] Verify monitoring still restores from saved preference and can be toggled by API.
- [ ] Run `swift test`.

### Task 3: Add Product Onboarding And Release Regression Docs

**Files:**
- Create: `docs/product/onboarding.md`
- Create: `docs/product/manual-regression.md`
- Modify: `Sources/DingDong/UsageGuidePanelView.swift`

- [ ] Document first-run setup: enable clipboard, grant accessibility, install MCP, add first resource, test notify.
- [ ] Document manual regression checks for menu bar, shortcut focus, clipboard text/image/file, resource edit, MCP bridge, settings, and update check.
- [ ] Add a compact first-run section to the in-app guide.
- [ ] Run `swift test`.

### Task 4: Verify And Package

**Files:**
- Existing packaging script: `scripts/package_app.sh`

- [ ] Run `swift test`.
- [ ] Run `DINGDONG_VERSION=0.2.0 DINGDONG_BUILD=2 scripts/package_app.sh`.
- [ ] Install `dist/DingDong.app` to `/Applications/DingDong.app`.
- [ ] Verify `/system/status` on the active local port.
