# Fix UI lag from iCloud stub downloads

Do this (in order):

- Trigger downloads and return; never wait on the main actor. Call `startDownloadingUbiquitousItem` and immediately show a placeholder.
- Move iCloud work off the main thread (non-@MainActor background service/actor). Post minimal UI updates back with `await MainActor.run { ... }`.
- Avoid full rescans. When one file finishes, read it off-main and update only that note; update tags incrementally for that note.
- Debounce and coalesce file-presenter events (≈1s) and skip refresh during initial load/active downloads.
- Keep reads off-main and security-scoped access short-lived.

Root cause: main-actor waits plus broad rescans/tag updates during downloads cause frame drops.
