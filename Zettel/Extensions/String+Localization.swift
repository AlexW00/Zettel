//
//  String+Localization.swift
//  Zettel
//
//  Created by GitHub Copilot on 08.07.25.
//
//  String extensions for localization support.
//

import Foundation

extension String {
    /// Returns the localized string for the given key
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments)
    }
}
