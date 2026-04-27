//
//  MacDockIconPreference.swift
//  ZettelMac
//
//  Persists and applies the macOS Dock icon visibility preference.
//

import AppKit

enum MacDockIconPreference {
    static let storageKey = "hideDockIcon"
    static let defaultIsHidden = false

    static func registerDefault() {
        UserDefaults.standard.register(defaults: [storageKey: defaultIsHidden])
    }

    static func isHidden() -> Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    @discardableResult
    @MainActor
    static func apply(isHidden: Bool) -> Bool {
        let activationPolicy: NSApplication.ActivationPolicy = isHidden ? .accessory : .regular
        let didSet = NSApplication.shared.setActivationPolicy(activationPolicy)
        if didSet {
            UserDefaults.standard.set(isHidden, forKey: storageKey)
        }
        return didSet
    }

    @MainActor
    static func applyCurrentValue() {
        let shouldHide = isHidden()
        let activationPolicy: NSApplication.ActivationPolicy = shouldHide ? .accessory : .regular
        let didSet = NSApplication.shared.setActivationPolicy(activationPolicy)
        if !didSet {
            let currentIsHidden = NSApplication.shared.activationPolicy() == .accessory
            UserDefaults.standard.set(currentIsHidden, forKey: storageKey)
        }
    }
}
