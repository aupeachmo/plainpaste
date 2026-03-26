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

## Security

The clipboard is untrusted input — any app (or malicious web content) can put arbitrary data on it. PlainPaste reads this data, so the question is whether a crafted clipboard payload could cause harm.

The attack surface is minimal. The data flow is: read a Swift `String` via `pb.string(forType: .string)`, clear the clipboard, write the same string back. The string is never parsed, interpreted, evaluated, or passed to a shell. There is no transformation where malicious input could alter control flow.

Swift's type system eliminates the classic C/C++ attack vectors: arrays are bounds-checked (no buffer overflows), memory is managed by ARC (no use-after-free), string interpolation is type-safe (no format string attacks), and integer arithmetic traps on overflow by default. The code uses no `UnsafePointer`, `UnsafeMutableBufferPointer`, or other unsafe constructs.

The release build includes the Hardened Runtime (`codesign --options runtime`), which enables additional OS-level protections: library validation, memory protection, and code signing enforcement. This is also required for notarization.

## What PlainPaste acts on — and what it ignores

PlainPaste only strips when the clipboard contains a rich-text type (`.rtf`, `.html`, or `.rtfd`) alongside a `.string` (plain text) representation. This is specifically the "I copied formatted text" scenario.

Everything else is left untouched:

- **Images** — no `.string` type present, so PlainPaste ignores them entirely.
- **File copies in Finder** — these use file URL types, not rich text.
- **Plain text** — if you copy text that has no rich formatting, there's nothing to strip.
- **Drag and drop** — uses a separate pasteboard (`NSDragPboard`), not `NSPasteboard.general`.
- **Screenshots, color swatches** — no text types present.

## Known edge cases

### Spreadsheet cells

When you copy cells from Excel, Numbers, or Google Sheets in a browser, the clipboard gets `.string` (tab-separated text), `.html` (table structure), and often `.rtf`. PlainPaste will strip those. If you paste into a text editor, that's fine — you get clean tab-separated data. But if you paste into another spreadsheet, the receiving app would have used the HTML to reconstruct cell structure, column widths, merged cells, and formulas. That structure is now gone.

If you're doing spreadsheet work, toggle PlainPaste off from the menu bar while you work, then toggle it back on.

### Links lose their URLs

If you copy "click here" where "here" is a hyperlink, the plain text is just "click here" — the URL is only in the HTML/RTF representation and gets stripped. This is usually the desired behaviour, but worth knowing.

### clearContents() is a sledgehammer

The `NSPasteboard` API doesn't allow selectively removing types. The only way to strip rich text is `clearContents()` followed by writing back the `.string`. This means any custom pasteboard types that apps put alongside rich text (such as `com.apple.iWork.TSPNativeData` from Pages) are also destroyed. In practice this rarely matters because the plain-text fallback is what PlainPaste is designed to produce.

### Intentional rich-text copying

If you're working in a rich-text editor (Pages, Word, Google Docs) and copying styled text to paste elsewhere in the same document, PlainPaste strips it. This is working as designed, but can surprise people who only want plain paste in some contexts. The toggle exists for this.

## User interface

PlainPaste is a menu-bar-only app — it has no Dock icon and no main window. Clicking the scissors icon in the menu bar shows a dropdown menu:

- **Strip Formatting: On / Off** — toggles auto-stripping. When off, PlainPaste still runs but does not touch the clipboard.
- **One-time strip** — strips the current clipboard contents once, regardless of the toggle state. Useful when you've turned auto-stripping off for spreadsheet work but want to clean one specific copy before pasting into a document.
- **About PlainPaste** — version info.
- **Quit PlainPaste** — exits the app.

### Menu bar icon states

The icon is the SF Symbol `scissors`. Its appearance changes to reflect whether stripping is active:

- **Enabled:** the icon renders as a **template image** — macOS draws it in the native menu-bar color (white in dark mode, black in light mode) and it adapts automatically to vibrancy and appearance changes. It looks like any other system icon.
- **Disabled:** the icon renders as the **scissors with a diagonal slash drawn through it**, matching the macOS convention for "off" states (`mic.slash`, `bell.slash`, `wifi.slash`, etc.). The slash is composited over the base symbol at render time using `NSImage`'s drawing API and the result is still a template image, so it adapts to light/dark mode just like the enabled state. No custom image assets are needed.
