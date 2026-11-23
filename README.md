# ghostpane

A monochrome, non-activating, capture-invisible (`NSWindow.sharingType = .none`) macOS floating overlay built in Swift/AppKit.

## Features
- **Stealth overlay:** Sharp 90° corners, non-activating `NSPanel`, invisible to screen sharing/recording, single-tap `⌥` (Option) visibility toggle, and `//` menubar icon.
- **Live Markdown & Persistence:** Smart markdown paste and live inline formatting, automatically saving text, window position/size, and opacity across restarts.
- **Adaptive compact UI:** Shrinks down to `150 × 150` px with a 2-row compact header so the opacity slider, `PASTE`, and `OCR` controls remain accessible.
- **PASTE mode (`⌘⇧P`):** Automatically answers pasted text via external `agy` (`gemini-4-hydrogen`, medium effort) right below the paste under an `agent-response:` badge.
- **OCR mode (`⌘⇧S`):** Silently captures the screen and answers visible questions/multiple-choice prompts concisely, delegating capture through LaunchServices when running as `root`.

## Build
```bash
./configure.sh
```
