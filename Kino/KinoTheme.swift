//
//  KinoTheme.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//

import SwiftUI

struct KinoTheme {
    static let bgPrimary = Color(hex: "0D0D0F")
    static let bgSecondary = Color(hex: "1C1C1E").opacity(0.95) // Adjusted to match
    static let bgTertiary = Color(hex: "28282A").opacity(0.8)
    static let accent = Color(hex: "6C5DD3")
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "6C5DD3"), Color(hex: "8A7AFF")],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let messageBg = Color(hex: "1C1C20").opacity(0.8)
    static let surfaceBorder = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.6)
}
