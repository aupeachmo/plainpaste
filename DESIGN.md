# Design

## What PlainPaste does

PlainPaste monitors the macOS system clipboard. When you copy something that contains rich-text formatting (RTF or HTML), it replaces the clipboard contents with the plain-text equivalent. The result: every paste is plain text, automatically.

## Architecture: polling

PlainPaste uses a 200ms polling timer to watch the clipboard. Every 200ms it reads `NSPasteboard.general.changeCount` (a simple integer), compares it to the last known value, and if it changed, checks whether the clipboard contains rich text alongside plain text. If so, it clears the clipboard and writes back only the plain text.

### Why polling?

macOS has no clipboard change notification. There is no `NSPasteboardDidChange`, no delegate callback, no `DispatchSource` for clipboard events. Apple never built one. Every clipboard-monitoring app on macOS polls — this is the standard and only approach.

### Why not intercept ⌘V instead?

An alternative architecture would skip clipboard monitoring entirely and instead intercept the paste keystroke globally, strip formatting at paste time, and forward the event to the active app. This has some appeal (zero latency, no polling) but significant downsides:

- **Requires Accessibility permissions.** Global key event interception needs the user to grant access in System Settings → Privacy & Security → Accessibility. PlainPaste's polling approach requires no permissions at all.
- **Fragile.** Some apps handle paste through non-standard code paths (custom responder chains, JavaScript in web views, etc). A global ⌘V intercept can miss these or interfere with them.
- **More complex.** Event taps, CGEvent callbacks, and the associated error handling add meaningful complexity for a utility that should be trivial.

Polling is simpler, more compatible, and permission-free. The tradeoff is a small latency window.

## Polling interval: 200ms

The timer fires 5 times per second. Each tick does one integer comparison (`changeCount != lastChangeCount`). If the clipboard hasn't changed — which is the case 99.9% of the time — it returns immediately.

When the clipboard *has* changed and contains rich text, the work is: one string read, one clear, one string write. This is a few microseconds of actual CPU work.

### Why not faster?

At 100ms (10 fires/sec) the latency improvement is negligible and the wake-up rate doubles. At 200ms the worst-case delay between copy and strip is ~250ms (200ms poll interval + 50ms intentional delay to avoid racing the source app). This is fast enough that a human cannot copy and paste before stripping completes under normal use.

### Why not slower?

At 500ms, a fast copy-paste sequence (muscle memory) can occasionally beat the strip. 200ms closes this gap without meaningful resource cost.

## Resource impact

### CPU

Each poll is an integer comparison — effectively free. When stripping occurs (rare relative to total ticks), the string read/clear/write cycle is a few microseconds. Activity Monitor will show 0.0% CPU.

### Memory

The app's total memory footprint is under 10 MB (mostly the Swift runtime and Cocoa framework overhead). The only data PlainPaste holds is a single `String` (the plain-text clipboard content) for the brief moment between read and write.

### Disk

None. Everything happens in RAM. `NSPasteboard` is an in-memory IPC mechanism managed by the `pboard` system daemon. PlainPaste never reads or writes any files during operation. The only disk access is the initial binary load at launch.

### Sleep

The polling timer does **not** prevent the machine from sleeping. macOS suspends all userspace timers when the system sleeps — the timer simply stops firing and resumes on wake. Only explicit power assertions (the `IOPMAssertionCreateWithName` API, used by video players and similar) can prevent sleep. A `Timer` is not a power assertion.

### Battery

The impact is negligible. Each 200ms wake-up is a few nanoseconds of work, and the OS coalesces timer fires with other system activity via timer coalescing (which is on by default). In practice this app will not appear in battery usage statistics.

## Permissions

PlainPaste requires **no special permissions**. `NSPasteboard.general` is a shared system resource that any app can read and write. No Accessibility access, no Full Disk Access, no Automation permissions, no user prompts.

## What PlainPaste preserves

When stripping, PlainPaste keeps only the `.string` (plain text) representation. It removes RTF, HTML, and any other types. This means:

- Copied images are left alone (no `.string` type present, so PlainPaste ignores them).
- File copies (Finder) are left alone (they use `NSFilenamesPboardType`, not rich text).
- If you copy text that has *only* plain text and no rich formatting, PlainPaste does nothing — it only acts when `.rtf` or `.html` types are present alongside `.string`.
