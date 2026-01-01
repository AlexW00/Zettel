//
//  ChangelogData.swift
//  Zettel
//
//  Static changelog data embedded in the app.
//  Add new changelog entries here when releasing a new version.
//

import Foundation

/// Static changelog entries embedded in the app
/// Add new entries at the TOP of the array (newest first)
enum ChangelogData {
    
    /// All changelog entries - add new versions at the TOP
    static let entries: [(version: String, title: String, content: String)] = [
        (
            version: "2.3",
            title: "v2.3 - What's New",
            content: """
            Welcome to Zettel v2.3!

            ## 🛠 Improvements

            - **Swipe Reliability**: Swiping to create a new note now flushes any pending auto-save first, so quick swipes won't lose last-second edits.
            
            ---

            Thank you for using Zettel! 💛
            """
        ),
        (
            version: "2.2",
            title: "v2.2 - What's New",
            content: """
            Welcome to Zettel v2.2!

            ## ✨ New Features

            - **Auto Save**: Notes are now automatically saved as you type, ensuring your work is never lost.
            
            ---

            Thank you for using Zettel! 💛
            """
        ),
        
        // Add older versions below as needed
        // (
        //     version: "2.3",
        //     title: "v2.3 - Previous Update",
        //     content: "..."
        // ),
    ]
}
