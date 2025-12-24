//
//  ExtensionLocalization.swift
//  BookmarkShareExtension
//
//  Extension için lokalizasyon helper
//

import Foundation

/// Extension Bundle'ından localized string al
func L(_ key: String) -> String {
    // Extension'ın kendi bundle'ından çeviriyi al
    return NSLocalizedString(key, tableName: "ShareExtension", bundle: .main, comment: "")
}

/// Extension Bundle'ından localized string al (format destekli)
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, tableName: "ShareExtension", bundle: .main, comment: "")
    return String(format: format, arguments: args)
}
