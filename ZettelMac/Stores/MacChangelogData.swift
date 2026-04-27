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
