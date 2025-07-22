# Contributing to Zettel

Thank you for your interest in contributing to Zettel! This guide will help you set up the project for development.

## Prerequisites

- macOS with Xcode 16.4 or later
- An Apple Developer Account (free account works for simulator testing)
- Git

## Development Setup

1. **Fork and Clone**

   ```bash
   git clone https://github.com/yourusername/Zettel.git
   cd Zettel
   ```

2. **Configure Environment**

   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` file** with your development settings:

   ```bash
   # Your Apple Developer Team ID (get from developer.apple.com)
   DEVELOPMENT_TEAM=XXXXXXXXXX

   # Your bundle identifier
   BUNDLE_IDENTIFIER=com.yourname.Zettel

   # Build settings (optional)
   CONFIGURATION=Debug
   SIMULATOR_DEVICE=iPhone 16
   ```

4. **Configure and Build**
   ```bash
   ./configure.sh  # Sets up Xcode project with your credentials
   ./build.sh      # Builds and runs tests
   ```

## Project Structure

- `Zettel/` - Main app source code
  - `Views/` - SwiftUI views
  - `Models/` - Data models
  - `Stores/` - State management
  - `Constants/` - App constants
  - `Extensions/` - Swift extensions
- `ZettelTests/` - Unit tests

## Development Workflow

1. **Before Making Changes**

   - Create a new branch: `git checkout -b feature/your-feature`
   - Make sure the project builds: `./build.sh`

2. **Making Changes**

   - Follow Swift coding conventions
   - Add tests for new functionality
   - Test on iOS Simulator

3. **Before Committing**

   - Run `./clean.sh` to remove personal configuration
   - Ensure `.env` is not committed (it's in `.gitignore`)
   - Test that the project builds from a clean state

4. **Submitting Changes**
   - Push your branch and create a Pull Request
   - Include a clear description of your changes

## Environment Files

- `.env.example` - Template with placeholder values (committed)
- `.env` - Your personal configuration (NOT committed, in `.gitignore`)

Never commit your personal `.env` file as it contains sensitive information.

## Scripts

- `./configure.sh` - Configure Xcode project with environment variables
- `./build.sh` - Build and test the project
- `./clean.sh` - Reset project to clean state (removes personal config)

## Troubleshooting

**"No Development Team" errors:**

- Make sure you've configured your `.env` file
- Run `./configure.sh` to apply your settings

**Build fails with signing errors:**

- Check your `DEVELOPMENT_TEAM` in `.env`
- Ensure you're signed into Xcode with your Apple ID

**Project file conflicts:**

- Run `./clean.sh` before committing
- The project file should not contain personal identifiers in commits
