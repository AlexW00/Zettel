# Zettel

A minimalist iOS note-taking app with a unique "tear-off" interaction pattern for archiving notes.

## Features

- **Single-note focus**: Edit one note at a time with full-screen interface
- **Tear gesture**: Archive notes by dragging from screen edges (mimics tearing paper)
- **Tag system**: Organize notes with hashtags (#tag)
- **Markdown support**: Plain text with markdown formatting
- **File integration**: Works with iOS Files app, exports/imports .md files
- **Themes**: Light, dark, and system theme options

## Requirements

- iOS 17.6+
- iPhone only (portrait orientation)
- Xcode 16.4+
- Apple Developer Account (for device deployment)

## Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd Zettel
   ```

2. **Configure your environment**
   ```bash
   cp .env.example .env
   ```
3. **Edit `.env` with your Apple Developer details:**
   - `DEVELOPMENT_TEAM`: Your Apple Developer Team ID (found in Apple Developer portal)
   - `BUNDLE_IDENTIFIER`: Your unique bundle identifier (e.g., `com.yourcompany.Zettel`)

## Building

```bash
./build.sh
```

Or run the configuration and build separately:

```bash
./configure.sh  # Configure project with your environment
# Then build in Xcode or use xcodebuild directly
```

## Development Scripts

- `./configure.sh` - Configure Xcode project with environment variables
- `./build.sh` - Configure and build the project
- `./clean.sh` - Reset project configuration to clean state
- `./clean-source.sh` - Remove personal information from source files

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and contribution guidelines.

## Usage

- **Create**: Start typing to create a new note
- **Archive**: Swipe from left/right edge and drag across screen to archive
- **View notes**: Swipe left to see archived notes
- **Tags**: Use #hashtags in your notes for organization
- **Settings**: Tap gear icon to change theme and storage location

## Storage

Notes are stored as Markdown files in your selected directory (default: Documents/). You can change the storage location in Settings and access files through the iOS Files app.
# Test change
