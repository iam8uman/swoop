# Swoop: Product Requirements Document

| | |
|---|---|
| Owner | Suman Sharma ([@iam8uman](https://github.com/iam8uman)) |
| Status | v1.0.1 shipped (October 2026) |
| Repo | https://github.com/iam8uman/swoop |
| Website | https://swoop-mac.vercel.app |
| License | MIT, free and open source |
| Platform | macOS 13+ (Apple silicon and Intel) |

This document explains what Swoop is, why it exists, how it is built and what comes next, so anyone (including future me) can pick it up quickly.

---

## 1. Summary

Swoop is a menu bar window manager for macOS. You hold a trigger key (Left ⌥ Option by default), flick the mouse toward where the focused window should go, and let go. A ring appears under the cursor, an outline previews where the window will land, and clicking while holding cycles through sizes (half → third → two thirds). The same actions are available as keyboard shortcuts while the trigger is held.

It was built over the Dashain 2026 holiday as an open-source side project, inspired by radial window managers like Loop. Swoop is an independent implementation with no shared code.

## 2. Problem

- Moving and resizing windows by dragging is slow and fiddly, especially on laptops.
- Snap tools like Rectangle need you to remember many shortcuts or aim at small targets.
- Tiling managers (yabai, AeroSpace, Amethyst) are powerful but rigid, and they reflow everything.

**What people want:** one muscle-memory gesture that puts a window where they want without looking, with keyboard shortcuts as a fallback.

## 3. Goals and non-goals

**Goals**
1. Snap the focused window to a common layout in under a second with one gesture.
2. Show what will happen before it happens (ring and preview), and make it easy to cancel.
3. Never get in the way of normal typing or clicking.
4. Install and first use in under two minutes, even without Apple notarization.
5. Stay native, light and private: no network, no account, only the Accessibility permission.

**Non-goals (for now)**
- Automatic tiling or a scrolling strip (that was a separate prototype, StripWM).
- Window management across Spaces or Mission Control.
- Windows or Linux versions.
- A paid tier.

## 4. Audience

- Mac users who juggle a browser, editor, terminal and notes on one or two screens.
- Developers and makers who like keyboard and mouse shortcuts but don't want to configure a tiling manager.
- The indie-hacker and build-in-public community on X, which is the main launch channel.

## 5. User experience

### 5.1 Core gesture
1. Hold the trigger key. After a short delay (0.15s by default) a ring appears at the cursor.
2. Move the cursor. Eight directions plus the centre map to actions. The highlighted slice and an outline show the result.
3. Click while holding to cycle through that direction's actions.
4. Release to apply. Esc or right-click cancels.

Default ring:

| Direction | Actions (cycle) |
|---|---|
| ← | Left half → left third → left two thirds |
| → | Right half → right third → right two thirds |
| ↑ | Maximize → almost maximize → top half |
| ↓ | Bottom half → bottom third → bottom two thirds |
| Diagonals | Quarters |
| Centre | Nothing (release without moving does nothing) |

### 5.2 Keyboard shortcuts (while the trigger is held)
Arrows for halves and thirds, ↩ maximize, C centre, F fullscreen, T centre third, 1–4 quarters, [ ] previous and next screen, ⇧+arrows move, = − larger and smaller, , . / stash, Z undo, I initial frame, M minimize, H hide. Pressing the same key again cycles. Keys that aren't Swoop shortcuts pass straight through.

### 5.3 Full action list
- **General:** maximize, almost maximize, fullscreen, centre, macOS centre, minimize, hide
- **Halves, quarters**, and **horizontal and vertical thirds**
- **Screens:** next, previous, left, right, top, bottom
- **Size and position:** larger, smaller, grow and shrink each edge, move in four directions
- **Stash:** tuck a window behind the left or right edge and reveal it on hover. Unstash puts it back.
- **More:** undo, initial frame, and user-defined custom layouts

### 5.4 Settings
General (launch at login, padding, step size, animation, cursor follows window, haptics, ignored apps, import/export/reset), Trigger (any combination of Fn, left/right ⌃⌥⌘⇧, hold delay, dead zone), Radial Menu (size, thickness, circle or rounded square, accent colour or custom colour, per-direction actions), Preview (padding, corners, border, fill, colour), Keybinds (recorder, conflicts, cycles), Layouts (custom fractions with a live thumbnail), Stash (sliver width, reveal on hover), About.

### 5.5 Automation
`swoop://` links for every action, for example `swoop://action/right-half`, `swoop://screen/next`, `swoop://direction/top-left`, `swoop://custom/<name>`, `swoop://stash/left`, `swoop://undo`, `swoop://settings`. Running `Swoop --list` prints every command.

### 5.6 Install and first run
- **One-liner:** `curl -fsSL https://swoop-mac.vercel.app/install.sh | bash` downloads the latest release into Applications, clears the quarantine flag and opens it.
- **Download:** unzip, drag to Applications, then follow macOS's first-run flow: "Not Opened" → Done → System Settings → Privacy & Security → Open Anyway → confirm. The website shows each screen.
- **Permission:** Accessibility only. Swoop polls for it and starts on its own once granted.

## 6. Technical design

### 6.1 Stack
Swift 5.9 Swift Package, AppKit and SwiftUI, no third-party dependencies. It runs as a menu bar app (`LSUIElement`). The bundle ID is `com.iam8uman.swoop`.

### 6.2 Modules
```
Sources/SwoopCore   Pure logic, no AppKit, unit-tested
  WindowAction        All actions, titles, symbols, unit rects
  ActionGeometry      Target frames, padding, resize/move, screen transfer, ScreenPicker, StashGeometry
  Interaction         RadialDirection math, CycleTracker, FrameHistory (undo)
  Settings            SwoopSettings, TriggerKey, Keybind, themes, forgiving Codable
  Commands            swoop:// URL parser and command list

Sources/Swoop       The app
  App/                main, AppDelegate (menu bar, permission, URL scheme), SettingsStore
  Windows/            AX helpers, AXWindow, Screens, FrameAnimator, WindowEngine, StashManager
  Trigger/            TriggerController (CGEventTap: modifiers, keys, mouse)
  Overlays/           OverlayPanel, RadialMenu, Preview
  Settings/           SwiftUI settings window
```

### 6.3 Key decisions
- **Accessibility API** (`AXUIElement`) to read and set window frames. The private `_AXUIElementGetWindow` gives stable window IDs, a common approach shared by yabai, Rectangle and AeroSpace.
- **CGEventTap** to detect the exact trigger key (left and right modifiers are distinct through device flag bits), track the mouse, and swallow only the keys and clicks Swoop handles.
- **Screen-space geometry** throughout (top-left origin, like AX), converted to AppKit coordinates only for overlays.
- **Animation:** a 120 Hz ease-out timer. If an app is slow to respond to AX calls, the window jumps straight to its final frame.
- **Settings** are stored as JSON in UserDefaults. Decoding is forgiving: unknown or broken fields fall back to defaults instead of wiping the user's setup.
- **Stash** refuses edges that touch another display, because the window would just appear there.

### 6.4 Build and release
- `scripts/build-app.sh` builds a universal binary, assembles `Swoop.app`, makes the icon and ad-hoc signs it.
- GitHub Actions on macOS 15 compiles, runs unit tests, builds the app and smoke-tests it (architectures, signature, `--version`, `--list`, and that it launches and stays up for 10 seconds). It then zips it.
- **Releasing:** bump `CFBundleShortVersionString` in `Resources/Info.plist` and push to `main`. If that version has no release yet, CI publishes `v<version>` with `Swoop.zip` and a checksum.
- The website (`website/`, static HTML/CSS/JS) deploys to Vercel on every push to `main` (root `vercel.json` sets `outputDirectory: website`).

### 6.5 Website
A single static page in Ubuntu / Ubuntu Mono on an indigo and blue palette. The hero is an interactive 3D Mac demo: hold ⌥ or press and hold, then flick. A walkthrough plays until the visitor takes over. The page then covers how it works, install (one-liner and illustrated first-run steps), the layout gallery, shortcuts and FAQ. The navbar GitHub button shows the live star count. The README embeds a recording of the same demo (`docs/demo.gif`, `docs/demo.mp4`).

## 7. Privacy and security
- No network access, analytics or accounts.
- One permission: Accessibility.
- Builds are not notarized (no Apple Developer Program membership yet), so macOS shows a first-run warning. The website and README explain why and how to proceed. The one-line installer avoids the warning by clearing the quarantine flag on a file downloaded straight from GitHub.

## 8. Success metrics
- GitHub stars and release downloads (GitHub API).
- Install completion: issues or feedback mentioning install trouble should trend to zero.
- Feedback and feature requests from the X launch posts.
- Qualitative: people saying they use it daily.

## 9. Known limitations
- Not notarized. macOS can treat each update as a new app, so the Accessibility toggle may need flipping after updates.
- While Left ⌥ is held, Swoop's shortcut keys override ⌥ shortcuts such as ⌥ + ← word jump. Users can switch to Right ⌥ or 🌐.
- Native fullscreen windows exit fullscreen before moving.
- Some apps enforce minimum sizes, so the final frame can differ slightly from the target.
- Tested end to end on one Mac so far (Apple silicon, recent macOS).

## 10. Roadmap
**Next (1.1)**
- Developer ID signing and notarization in CI (needs the $99/year Apple program), plus automatic updates through Sparkle.
- Homebrew cask (`brew install --cask swoop`).
- An onboarding window that walks through permission and the first flick.
- Per-app default layouts.

**Later**
- Trackpad gesture trigger (three-finger flick).
- Window groups and saved workspaces ("coding", "writing").
- Snap by dragging a window to screen edges.
- Localisation.

## 11. Decision log
| Date | Decision |
|---|---|
| 2026-10-20 | Name **Swoop**, MIT license, theming follows the macOS accent colour |
| 2026-10-20 | Separate from the StripWM scrolling-strip prototype |
| 2026-10-20 | Release by bumping the version on `main` (tag pushes were blocked from the build environment) |
| 2026-10-20 | Default trigger changed from Right ⌥ to **Left ⌥** (v1.0.1) |
| 2026-10-20 | One-line installer and illustrated first-run guide added to the site |
| 2026-10-20 | Website type set in Ubuntu, original blue palette kept |
