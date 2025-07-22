# Zettel iOS App - Codebase Overview

## Project Summary

Zettel is a minimalist iOS markdown note-taking app with a unique "tear-off" interaction pattern. The app focuses on single-note editing with a distinctive archiving mechanism through physical tear gestures.

## Technical Stack

- **Platform**: iOS 17.6+
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI with UIKit integration
- **Architecture**: MVVM with Document-Based App architecture
- **Storage**: File-based (.md files) with extended attributes for metadata
- **Device Support**: iPhone only (portrait orientation)

## Core Features

1. **Single-Note Focus**: One active note at a time with full-screen editing
2. **Tear-Off Archiving**: Physical drag gesture from edges to archive notes
3. **Tag System**: Hashtag-based organization with visual tag chips
4. **Document Integration**: Full iOS Files app integration
5. **Markdown Support**: Custom keyboard toolbar for formatting
6. **Theme Support**: Light, dark, and system theme options

## Architecture Overview

### Models (`/Zettel/Models/`)

- **Note.swift**: Core note model with metadata serialization
- **Tag.swift**: Tag model with case-insensitive matching
- **TagParser.swift**: Regex-based tag extraction from content

### Stores (`/Zettel/Stores/`)

- **NoteStore.swift**: Central state management for notes
- **TagStore.swift**: Tag usage tracking and management
- **ThemeStore.swift**: Theme preference persistence

### Views (`/Zettel/Views/`)

- **MainView.swift**: Primary editing interface with tear gesture
- **OverviewGrid.swift**: Archived notes grid with filtering
- **SwipeNavigationView.swift**: Container for swipe navigation
- **TaggableTextEditor.swift**: Text editor with tag highlighting
- **SettingsView.swift**: App configuration interface
- **TagChipView.swift**: Tag visualization components

### Extensions (`/Zettel/Extensions/`)

- **String+Localization.swift**: Localization support
- **Color+Extensions.swift**: Custom color definitions
- **CGFloat+Extensions.swift**: Safe math operations

### Constants (`/Zettel/Constants/`)

- **LayoutConstants.swift**: UI spacing, sizes, animation durations
- **ThemeConstants.swift**: Color opacity and visual constants

## Data Flow

1. **Note Creation**: User writes → Save on tear → Create .md file
2. **Note Loading**: Read .md files → Parse metadata → Display in grid
3. **Tag Extraction**: Regex parsing → Cache management → UI updates
4. **File Sync**: NSFilePresenter → External change detection → Auto-reload

## File Format

Notes are stored as plain Markdown files:

```markdown
Note content with #tags and markdown formatting
```

## Key Technologies

- **SwiftUI**: Primary UI framework
- **UIKit**: Text editing (UITextView) and document picker
- **Combine**: Implicit reactive state management via @Published properties
- **FileManager**: File operations and monitoring
- **NSFilePresenter**: External file change detection
- **Haptic Feedback**: Physical feedback for interactions

## Storage Structure

- **Default Location**: `Documents/`
- **File Format**: Markdown (.md) files
- **Tag Extraction**: Dynamic regex-based parsing
- **Security**: App sandbox with user-selected file access

## App Capabilities

- ✅ Document-based app
- ✅ File sharing (iTunes)
- ✅ Opens documents in place
- ✅ User-selected file access
- ❌ No network access

## Build Configuration

- **Bundle ID**: Configurable via environment file
- **Version**: 1.0
- **Minimum iOS**: 17.6
- **Swift Version**: 5.0
- **Xcode Project**: Modern format with automatic signing

## UI/UX Design Principles

1. **Minimalist Interface**: Focus on content, not chrome
2. **Physical Metaphors**: Tear gesture mimics real paper
3. **Haptic Feedback**: Reinforces physical interactions
4. **Smooth Animations**: Spring animations for natural feel
5. **Consistent Theming**: System-aware color scheme

## Performance Considerations

- **Lazy Loading**: Notes loaded on demand
- **Tag Caching**: `TagCacheManager` for regex performance
- **File Monitoring**: Efficient external change detection
- **Memory Management**: Automatic with ARC

## Security & Privacy

- **Sandboxed**: Full app sandbox
- **File Access**: Only user-selected files
- **No Analytics**: No tracking or data collection

## Development History

Recent development focuses on:

- Tag animation improvements
- Color system refinements
- Keyboard functionality fixes
- File naming enhancements
- Welcome note for first-time users

## Project Structure

```
Zettel/
├── Zettel.xcodeproj/       # Xcode project files
├── Zettel/                 # Main app source
│   ├── Assets.xcassets/     # App icons and colors
│   ├── Extensions/          # Swift extensions
│   ├── Models/              # Data models
│   ├── Stores/              # State management
│   ├── Views/               # UI components
│   ├── Constants/           # Design system constants
│   ├── ZettelApp.swift     # App entry point
│   └── ContentView.swift    # Main container
├── plan/                   # Development planning docs
├── build.sh               # Build script
└── README.md              # Basic project info
```

## Third-Party Dependencies

None - The app uses only Apple frameworks, demonstrating a lean, native-first approach.

## Testing Infrastructure

Currently no automated tests. The app relies on manual testing and Xcode previews for UI validation.

## Notable Architectural Decisions

1. **File-Based Storage**: Simple, user-accessible, no database complexity
2. **Document-Based App**: Leverages iOS document management
3. **Tag Extraction**: Dynamic regex-based rather than stored relationships
4. **Single Activity Focus**: One note at a time reduces complexity
5. **No Cloud Sync**: Simplifies data management and privacy
6. **UIKit Integration**: Custom text editing with SwiftUI wrapper
7. **NSFilePresenter**: Automatic external file change detection

## Key Classes

### NoteStore

Central state manager handling:

- File I/O operations
- Note lifecycle management
- External file monitoring via NSFilePresenter
- Tag store coordination
- First-time user experience

### Note Model

Simple structure with:

- Title and content properties
- Creation/modification timestamps
- Auto-generated titles from timestamps
- Tag extraction via regex
- Filename-based identity

### TagStore

Manages tag-related functionality:

- Tag extraction caching
- Usage count tracking
- Debounced updates for performance
- Tag-based note filtering

### UI Components

- **MainView**: Single-note editing with tear gesture
- **OverviewGrid**: Masonry-style grid of archived notes
- **TaggableTextEditor**: UIKit text view with tag suggestions
- **SwipeNavigationView**: Container managing swipe transitions

## File System Integration

The app integrates deeply with iOS file system:

- Security-scoped resource access for user-selected directories
- NSFileCoordinator for safe file operations
- File monitoring for external changes
- Document picker integration
- Support for opening .md files from Files app

## Performance Optimizations

- Tag extraction caching to avoid repeated regex operations
- Debounced tag store updates during typing
- Lazy loading of note content
- Efficient grid layout with proper sizing calculations
- Memory-conscious image and asset loading
