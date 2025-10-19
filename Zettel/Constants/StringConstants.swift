//
//  StringConstants.swift
//  Zettel
//
//  Created by GitHub Copilot on 25.07.25.
//
//  Centralized string constants for localization support.
//

import Foundation

/// Centralized string constants for consistent localization throughout the app
enum StringConstants {
    
    // MARK: - General Actions
    enum Actions {
        static let done = "general.done"
        static let cancel = "general.cancel"
        static let save = "general.save"
        static let delete = "general.delete"
        static let edit = "general.edit"
        static let ok = "general.ok"
        static let change = "general.change"
    }
    
    // MARK: - Navigation & Titles
    enum Navigation {
        static let settings = "navigation.settings"
        static let about = "navigation.about"
        static let storage = "navigation.storage"
    }
    
    // MARK: - Note Interface
    enum Note {
        static let titlePlaceholder = "note.title_placeholder"
        static let untitled = "note.untitled"
        static let emptyNote = "note.empty"
        static let tearZoneAccessibility = "note.tear_zone_accessibility"
    }
    
    // MARK: - Settings Screen
    enum Settings {
        static let displaySection = "settings.display"
        static let storageSection = "settings.storage"
        static let aboutSection = "settings.about"
        static let storageLocation = "settings.storage_location"
        static let storageDescription = "settings.storage_description"
        static let appName = "settings.app_name"
        static let appDescription = "settings.app_description"
        static let systemThemeDescription = "settings.system_description"
        static let developer = "settings.developer"
        static let developerDescription = "settings.developer_description"
        static let viewOnGitHub = "settings.view_on_github"
        static let fontSize = "settings.font_size"
        static let fontSizeDescription = "settings.font_size_description"
        static let defaultTitleTemplate = "settings.default_title_template"
        static let defaultTitleTemplateDescription = "settings.default_title_template_description"
        static let defaultTitleTemplatePlaceholder = "settings.default_title_template_placeholder"
        static let defaultTitleTemplateInfoTitle = "settings.default_title_template_info_title"
        static let defaultTitleTemplateInfoMessage = "settings.default_title_template_info_message"
        static let defaultTitleTemplateInfoButton = "settings.default_title_template_info_button"
        static let dictationSection = "dictation.settings.section_title"
        static let dictationSectionDescription = "dictation.settings.section_description"
        static let dictationLocaleMenuLoading = "dictation.locale.download.in_progress"
    }
    
    // MARK: - Overview & Archive
    enum Overview {
        static let allNotes = "overview.all_notes"
        static let emptyStateMessage = "overview.empty_state_message"
        static let tagCount = "overview.tag_count"
        static let additionalTags = "overview.additional_tags"
    }
    
    // MARK: - Search
    enum Search {
        static let prompt = "search.prompt"
        static let noResultsTitle = "search.no_results_title"
        static let noResultsMessage = "search.no_results_message"
    }

    // MARK: - Theme Options
    enum Theme {
        static let system = "theme.system"
        static let light = "theme.light"
        static let dark = "theme.dark"
    }
    
    // MARK: - Tags
    enum Tags {
        static let hashtagPrefix = "tags.hashtag_prefix"
        static let noTags = "tags.no_tags"
    }
    
    // MARK: - Error Messages
    enum Errors {
        // Note Errors
        static let corruptedFile = "error.corrupted_file"
        static let fileSystemError = "error.file_system_error"
        static let encodingError = "error.encoding_error"
        
        // Validation Errors
        static let titleTooLong = "error.title_too_long"
        static let contentTooLong = "error.content_too_long"
        static let tooManyTags = "error.too_many_tags"
        static let tagTooLong = "error.tag_too_long"
    }
    
    // MARK: - Accessibility
    enum Accessibility {
        static let tearZone = "accessibility.tear_zone"
    static let tearZoneHint = "accessibility.tear_zone_hint"
        static let settingsButton = "accessibility.settings_button"
        static let selectionMode = "accessibility.selection_mode"
        static let noteCard = "accessibility.note_card"
    }
    
    // MARK: - Shortcuts
    enum Shortcuts {
        static let createNewNote = "shortcuts.create_new_note"
        static let createNewNoteDescription = "shortcuts.create_new_note_description"
        static let newNoteShortTitle = "shortcuts.new_note_short_title"
        static let confirmationTitle = "shortcuts.confirmation_title"
        static let confirmationMessage = "shortcuts.confirmation_message"
    }
    
    // MARK: - Loading States
    enum Loading {
        static let loadingNotes = "loading.loading_notes"
        static let loadingSubtitle = "loading.loading_subtitle"
        static let loadingError = "loading.loading_error"
        static let retryButton = "loading.retry_button"
    }

    // MARK: - Dictation & Speech
    enum Dictation {
        static let startButton = "dictation.button.start"
        static let stopButton = "dictation.button.stop"
        static let permissionDeniedTitle = "dictation.error.permission_denied.title"
        static let permissionDeniedMessage = "dictation.error.permission_denied.message"
        static let localeMissingTitle = "dictation.error.locale_missing.title"
        static let localeMissingMessage = "dictation.error.locale_missing.message"
        static let analyzerUnavailableTitle = "dictation.error.analyzer_unavailable.title"
        static let analyzerUnavailableMessage = "dictation.error.analyzer_unavailable.message"
        static let transcriptionFailedTitle = "dictation.error.transcription_failed.title"
        static let downloadFailedTitle = "dictation.error.download_failed.title"
        static let localeDownloadTitle = "dictation.locale.download.title"
        static let localeDownloadMessage = "dictation.locale.download.message"
        static let localeDownloadConfirm = "dictation.locale.download.confirm"
        static let localeDownloadInProgress = "dictation.locale.download.in_progress"
        static let localeCellInstalled = "dictation.locale.installed"
        static let localeCellPending = "dictation.locale.pending"
    }
}
