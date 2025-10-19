//
//  DictationLocaleManager.swift
//  Zettel
//
//  Created by Codex on 19.10.25.
//
//  Manages available locales for the speech dictation pipeline using the
//  iOS 26 Speech SDK (SpeechTranscriber/AssetInventory).
//

import Foundation
@preconcurrency import Speech

@MainActor
final class DictationLocaleManager: ObservableObject {
    struct LocaleOption: Identifiable, Equatable {
        let id: String
        let locale: Locale
        let displayName: String
        let languageCode: String
        fileprivate(set) var isInstalled: Bool

        init(locale: Locale, currentLocale: Locale, isInstalled: Bool) {
            self.locale = locale
            self.id = locale.identifier
            self.languageCode = locale.identifier
            let localizedName = currentLocale.localizedString(forIdentifier: locale.identifier)
            let autonym = locale.localizedString(forIdentifier: locale.identifier)
            if let localizedName, let autonym, localizedName != autonym {
                self.displayName = "\(localizedName) · \(autonym.capitalized)"
            } else {
                self.displayName = localizedName ?? autonym ?? locale.identifier
            }
            self.isInstalled = isInstalled
        }
    }

    static let shared = DictationLocaleManager()

    @Published private(set) var localeOptions: [LocaleOption] = []
    @Published private(set) var installedLocaleIdentifiers: Set<String> = []
    @Published var selectedLocaleIdentifier: String
    @Published private(set) var isLoadingLocales = false
    @Published private(set) var lastError: Error?

    private let defaultsKey = "dictation.selectedLocaleIdentifier"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let stored = userDefaults.string(forKey: defaultsKey) {
            selectedLocaleIdentifier = stored
        } else {
            selectedLocaleIdentifier = Locale.current.identifier
        }

        Task { await loadLocalesIfNeeded() }
    }

    func loadLocalesIfNeeded() async {
        if !localeOptions.isEmpty { return }
        await reloadLocales()
    }

    func reloadLocales() async {
        isLoadingLocales = true
        lastError = nil
        let currentLocale = Locale.current

        let supportedLocales = await SpeechTranscriber.supportedLocales
        let installedLocales = await SpeechTranscriber.installedLocales
        let installed = Set(installedLocales.map { $0.identifier })
        installedLocaleIdentifiers = installed

        let sortedLocales = supportedLocales.sorted { lhs, rhs in
            let lhsName = currentLocale.localizedString(forIdentifier: lhs.identifier) ?? lhs.identifier
            let rhsName = currentLocale.localizedString(forIdentifier: rhs.identifier) ?? rhs.identifier
            if lhsName == rhsName {
                return lhs.identifier < rhs.identifier
            }
            return lhsName < rhsName
        }

        localeOptions = sortedLocales.map { locale in
            LocaleOption(locale: locale, currentLocale: currentLocale, isInstalled: installed.contains(locale.identifier))
        }
        ensureSelectionIsValid()

        isLoadingLocales = false
    }

    func ensureSelectionIsValid() {
        if localeOptions.first(where: { $0.id == selectedLocaleIdentifier }) == nil,
           let fallback = localeOptions.first {
            selectedLocaleIdentifier = fallback.id
            persistSelection()
        }
    }

    func refreshInstalledLocales() async {
        let installedLocales = await SpeechTranscriber.installedLocales
        installedLocaleIdentifiers = Set(installedLocales.map { $0.identifier })
        updateInstallationFlags()
    }

    func markLocaleInstalled(_ locale: Locale) {
        installedLocaleIdentifiers.insert(locale.identifier)
        updateInstallationFlags()
    }

    func markLocaleUninstalled(_ locale: Locale) {
        installedLocaleIdentifiers.remove(locale.identifier)
        updateInstallationFlags()
    }

    func localeOption(for identifier: String? = nil) -> LocaleOption? {
        let identifier = identifier ?? selectedLocaleIdentifier
        return localeOptions.first(where: { $0.id == identifier })
    }

    func selectedLocale() -> Locale {
        if let option = localeOption() {
            return option.locale
        }
        return Locale(identifier: selectedLocaleIdentifier)
    }

    func updateSelectedLocale(_ option: LocaleOption) {
        guard option.id != selectedLocaleIdentifier else { return }
        selectedLocaleIdentifier = option.id
        persistSelection()
    }

    func localeRequiresDownload(_ locale: Locale) -> Bool {
        !installedLocaleIdentifiers.contains(locale.identifier)
    }

    private func persistSelection() {
        userDefaults.set(selectedLocaleIdentifier, forKey: defaultsKey)
    }

    private func updateInstallationFlags() {
        localeOptions = localeOptions.map { option in
            var copy = option
            copy.isInstalled = installedLocaleIdentifiers.contains(option.id)
            return copy
        }
    }
}
