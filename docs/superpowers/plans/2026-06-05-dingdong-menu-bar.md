# DingDong Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar utility that lets local AI agents trigger a visible and audible "ding dong" reminder through a local HTTP API.

**Architecture:** A native Swift/AppKit executable owns the menu bar status item, a popover UI, sound playback, and a loopback-only HTTP server. The server parses small HTTP requests and dispatches notification effects back onto the main thread.

**Tech Stack:** Swift Package Manager, AppKit, SwiftUI, AVFoundation, Network.framework, XCTest.

---

### Task 1: Project Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/DingDong/main.swift`

- [x] **Step 1: Define Swift package targets**

Run: `swift build`
Expected: The package manifest is accepted and compilation starts.

### Task 2: Reminder Domain

**Files:**
- Create: `Sources/DingDong/DingRequest.swift`
- Test: `Tests/DingDongTests/DingRequestTests.swift`

- [x] **Step 1: Parse JSON request bodies**

Run: `swift test --filter DingRequestTests`
Expected: JSON request payloads decode into a command with default values.

### Task 3: Local API Server

**Files:**
- Create: `Sources/DingDong/NotificationServer.swift`
- Test: `Tests/DingDongTests/HTTPRouteTests.swift`

- [x] **Step 1: Add loopback HTTP routes**

Run: `swift test --filter HTTPRouteTests`
Expected: `/health`, `/ding`, and unknown routes produce stable responses.

### Task 4: Menu Bar App

**Files:**
- Create: `Sources/DingDong/AppDelegate.swift`
- Create: `Sources/DingDong/StatusController.swift`
- Create: `Sources/DingDong/ControlPanelView.swift`
- Create: `Sources/DingDong/SoundPlayer.swift`

- [x] **Step 1: Add status item, popover, flashing icon, and sound selection**

Run: `swift build`
Expected: The native macOS executable compiles.

### Task 5: Documentation

**Files:**
- Create: `README.md`

- [x] **Step 1: Document usage**

Run: `swift run DingDong`, then `curl -X POST http://127.0.0.1:8765/ding -H 'Content-Type: application/json' -d '{"message":"done"}'`
Expected: The menu bar icon flashes and the configured sound plays.
