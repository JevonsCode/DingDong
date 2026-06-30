# DingDong AI Companion Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand DingDong from a macOS reminder utility into a lightweight AI companion with cheerful alerts, resource storage, clipboard capture, and local APIs for multiple AI agents.

**Architecture:** Keep the app as a native menu bar process with a loopback HTTP API. Add a small JSON-backed resource library instead of heavy background services; clipboard capture starts explicit and opt-in to protect CPU and memory.

**Tech Stack:** Swift Package Manager, AppKit, SwiftUI, AVFoundation, Network.framework, JSON persistence, XCTest/Swift Testing.

---

### Task 1: Architecture and Product Direction

**Files:**
- Create: `docs/architecture/ai-companion-architecture.md`
- Create: `docs/superpowers/plans/2026-06-05-ai-companion-expansion.md`

- [x] **Step 1: Document UX, architecture, API, and performance constraints**

Run: `test -f docs/architecture/ai-companion-architecture.md`
Expected: exit 0.

### Task 2: Cheerful Sound Profile

**Files:**
- Modify: `Sources/DingDong/SoundPlayer.swift`

- [ ] **Step 1: Replace the built-in default with a short happy chime sequence**

Use existing macOS sounds to avoid large bundled audio assets.

Run: `swift test`
Expected: all tests pass and no compile errors.

### Task 3: Resource Library Model

**Files:**
- Create: `Sources/DingDong/ResourceItem.swift`
- Create: `Sources/DingDong/ResourceStore.swift`
- Test: `Tests/DingDongTests/ResourceStoreTests.swift`

- [ ] **Step 1: Add resource type and item model**

Run: `swift test --filter ResourceStoreTests`
Expected: resource encoding, default groups, and filtering pass.

### Task 4: Library API

**Files:**
- Modify: `Sources/DingDong/NotificationRouter.swift`
- Modify: `Sources/DingDong/AppDelegate.swift`
- Test: `Tests/DingDongTests/HTTPRouteTests.swift`

- [ ] **Step 1: Add `GET /library` and `POST /library`**

Run: `swift test --filter HTTPRouteTests`
Expected: library routes return JSON and mutate the injected store.

### Task 5: Clipboard Capture API

**Files:**
- Create: `Sources/DingDong/ClipboardRecorder.swift`
- Modify: `Sources/DingDong/NotificationRouter.swift`
- Test: `Tests/DingDongTests/ClipboardRecorderTests.swift`

- [ ] **Step 1: Capture current text pasteboard only on explicit request**

Run: `swift test --filter ClipboardRecorderTests`
Expected: empty pasteboard and text pasteboard cases are handled.

### Task 6: Companion Panel UI

**Files:**
- Modify: `Sources/DingDong/ControlPanelView.swift`
- Modify: `Sources/DingDong/StatusController.swift`

- [ ] **Step 1: Add compact tabs for Today, Library, Clipboard, API**

Run: `swift build`
Expected: build passes and the panel remains compact.

### Task 7: Documentation and Agent Prompt

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document Codex prompt snippets and resource APIs**

Run: `swift test && swift build`
Expected: all tests and build pass.
