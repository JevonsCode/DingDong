# DingDong Manual Regression Checklist

Run this checklist before publishing a release. Unit tests cover model and route behavior, but these system interactions need manual verification on macOS.

## Menu Bar And Window

- Left-click the menu bar icon opens the panel on the first click.
- Left-click again hides the panel.
- Right-click opens the menu with settings, guide, clipboard toggle, and quit.
- The panel appears below the menu bar with visible top spacing.
- The panel hide/show animation is quick and does not block typing.
- Pressing Escape closes the panel.

## Clipboard

- `Command-Shift-V` opens and closes the Clipboard tab.
- Opening from a text input does not permanently steal focus.
- `Command-1` through `Command-9` paste visible clipboard rows, counted from the current visible list.
- Single-click previews a clipboard item.
- Double-click pastes a clipboard item.
- Up/down keyboard navigation changes selection.
- Space previews the selected item.
- Return uses the selected item.
- Text, URL, command, code, path strings, image files, and copied bitmap images appear in history.
- Plain text paths remain text unless macOS placed real file URLs on the pasteboard.
- Clipboard retention defaults show 1000 items and 90 days.

## Resource Library

- Resource Manager opens from the Library tab.
- Prompt, Skill, MCP, and Knowledge resources can be created, edited, pinned, copied, and deleted.
- Tags wrap cleanly and do not collapse to unreadable ellipses.
- Resource cards keep consistent width and action button layout.

## MCP Bridge

- `dingdong_bridge` returns summary-first prompts, skills, and MCP references.
- `dingdong_load_skill` returns full skill content by id.
- `dingdong_get_asset` hides clipboard content unless explicitly requested.
- `dingdong_notify` changes the menu bar icon once and clears after opening DingDong.
- Agents call notification once per user-visible task, not after every intermediate segment.

## Settings

- Launch at login switch reads and writes the macOS login item state.
- Accessibility section shows granted state after restart.
- Version check reaches the GitHub Pages JSON and handles failure without blocking settings.
- API section exposes MCP setup help and test action.
- Appearance opacity changes affect the summoned panel.
- Sound choices are unique and playable.

## Packaging

- `swift test` passes.
- `scripts/package_app.sh` produces `dist/DingDong.app`.
- Installing to `/Applications/DingDong.app` starts the app.
- `/system/status` returns `status: ok` on the active local port.

