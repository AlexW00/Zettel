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
            version: "3.2",
            title: "v3.2 - More Apps",
            content: """
            ## ✨ New

            - **More Apps**: Settings now links to [apps.weichart.de](https://apps.weichart.de), where you can find my other apps ^^

            ---

            Thank you for using Zettel! 💛
            """
        ),
        (
            version: "3.1",
            title: "v3.1 - 🖥 Zettel for Mac",
            content: """
            ## 🖥 Zettel for Mac - NEW

            Zettel is now available on macOS!

            You can download it on the App Store by searching for "Zettel - Quick Notes" or Air-Dropping this Zettel to your Mac.

            ## 🛠 Improvements

            - **Tag Suggestions**: Tag suggestion pills now use liquid glass.

            ---

            Thank you for using Zettel! 💛
            """
        ),
        (
            version: "3.0",
            title: "v3.0 - 🎨 Make It Yours",
            content: """
            ## ✨ New Features

            - **Custom Backgrounds**: Personalize your Zettel background with your favorite image or set a calming video loop.
            - **Background Settings**: Fine-tune your background with dimming, loop fade, and volume controls.
            - **Improved Search**: Quickly find what you need with the new collapsible search bar.
            
            Open the settings to change your background now!
            
            ---

            Thank you for using Zettel! 💛
            """
        ),
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
