//
//  MacChangelogData.swift
//  ZettelMac
//
//  Static changelog data for the macOS app.
//  Add new changelog entries at the TOP of the array (newest first).
//

import Foundation

enum MacChangelogData {

    /// All changelog entries - add new versions at the TOP
    static let entries: [(version: String, title: String, content: String)] = [
        (
            version: "1.6",
            title: "v1.6 - Font Alignment with iOS",
            content: """
            ## ✨ Improvements

            - **Monospaced Editor Font**: The note editor now uses the same monospaced system font as the iOS app, so notes look consistent across both platforms.
            - **Live Font Size Slider**: Dragging the **Font Size** slider in Settings now updates open editors immediately — no need to reopen a window.
            - **Matching Title & Tag Fonts**: The toolbar title, sidebar rename popover, and tag autocomplete suggestions now use the monospaced design used on iOS.

            ---

            Thank you for using Zettel!
            """
        ),
        (
            version: "1.5",
            title: "v1.5 - Japanese Input Fix",
            content: """
            ## 🛠 Fix

            - **Japanese Keyboard (IME)**: Fixed a bug where characters would disappear when cycling through kanji candidates. Composing text with the Japanese input method now works reliably.

            ---

            Thank you for using Zettel!
            """
        ),
        (
            version: "1.4",
            title: "v1.4 - Settings, More Apps & Dock Fix",
            content: """
            ## ✨ New

            - **Settings in Toolbar**: A gear icon now sits at the top-right of every window so you can jump into Settings without hunting through the menu bar.
            - **More Apps**: Settings now links to [apps.weichart.de](https://apps.weichart.de), where you can find my other apps ^^

            ## 🛠 Fix

            - **Dock & App Switcher**: Zettel now opens as a regular Dock app on first launch, with a running-indicator dot, its own Stage Manager space, and Cmd+Tab support. You can still hide the Dock icon any time from Settings.

            ---

            Thank you for using Zettel!
            """
        ),
        (
            version: "1.3",
            title: "v1.3 - Reliability Update",
            content: """
            ## Bug Fix

            Fixed a bug where the **sidebar appeared empty** after a system restart or app update, requiring you to re-select your notes folder in Settings.

            ## Action Required

            Because of how this fix works, you'll need to **re-select your notes folder one last time**:

            1. Open **Settings** (Cmd + ,)
            2. Click **Change...** next to Storage Location
            3. Select your notes folder

            After this, your folder choice will persist correctly through future restarts and updates.

            ---

            Thank you for using Zettel!
            """
        ),
    ]
}
