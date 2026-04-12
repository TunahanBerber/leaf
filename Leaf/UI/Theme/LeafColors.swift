import SwiftUI

// light ve dark mod renk tokenlarını burada topladım
// her renk her iki modda ayrı ton kullanıyor
// en altta adaptive helper'lar var — colorScheme vererek doğru rengi alıyorsun

enum LeafColors {
    // MARK: - Marka Renkleri
    static let primary = Color("AccentColor")
    static let primaryLight = Color(red: 47/255, green: 125/255, blue: 92/255)
    static let primaryDark = Color(red: 73/255, green: 192/255, blue: 141/255)

    // MARK: - Gradient Arka Plan
    static let bgTopLight = Color(red: 250/255, green: 251/255, blue: 252/255)
    static let bgBottomLight = Color(red: 154/255, green: 191/255, blue: 241/255)
    static let bgTopDark = Color.black
    static let bgBottomDark = Color(red: 3/255, green: 11/255, blue: 35/255)

    // MARK: - Yüzey Renkleri (cam efekti katmanları)
    static let surfacePrimaryLight = Color.white.opacity(0.78)
    static let surfaceSecondaryLight = Color.white.opacity(0.64)

    static let surfacePrimaryDark = Color(red: 24/255, green: 25/255, blue: 31/255).opacity(0.72)
    static let surfaceSecondaryDark = Color(red: 24/255, green: 25/255, blue: 31/255).opacity(0.56)

    // MARK: - Metin Renkleri (üç kademe hiyerarşi)
    static let textPrimaryLight = Color(red: 12/255, green: 14/255, blue: 18/255).opacity(0.92)
    static let textSecondaryLight = Color(red: 12/255, green: 14/255, blue: 18/255).opacity(0.70)
    static let textTertiaryLight = Color(red: 12/255, green: 14/255, blue: 18/255).opacity(0.52)

    static let textPrimaryDark = Color(red: 245/255, green: 246/255, blue: 248/255).opacity(0.92)
    static let textSecondaryDark = Color(red: 245/255, green: 246/255, blue: 248/255).opacity(0.70)
    static let textTertiaryDark = Color(red: 245/255, green: 246/255, blue: 248/255).opacity(0.52)

    // MARK: - Border Renkleri
    static let borderSubtleLight = Color(red: 15/255, green: 18/255, blue: 22/255).opacity(0.06)
    static let borderPrimaryLight = Color(red: 15/255, green: 18/255, blue: 22/255).opacity(0.10)

    static let borderSubtleDark = Color(red: 245/255, green: 246/255, blue: 248/255).opacity(0.08)
    static let borderPrimaryDark = Color(red: 245/255, green: 246/255, blue: 248/255).opacity(0.14)
}

// MARK: - Adaptive helpers
extension LeafColors {
    static func textPrimary(for s: ColorScheme) -> Color { s == .dark ? textPrimaryDark : textPrimaryLight }
    static func textSecondary(for s: ColorScheme) -> Color { s == .dark ? textSecondaryDark : textSecondaryLight }
    static func textTertiary(for s: ColorScheme) -> Color { s == .dark ? textTertiaryDark : textTertiaryLight }
    static func surfacePrimary(for s: ColorScheme) -> Color { s == .dark ? surfacePrimaryDark : surfacePrimaryLight }
    static func borderSubtle(for s: ColorScheme) -> Color { s == .dark ? borderSubtleDark : borderSubtleLight }
    static func borderPrimary(for s: ColorScheme) -> Color { s == .dark ? borderPrimaryDark : borderPrimaryLight }
    static func accent(for s: ColorScheme) -> Color { s == .dark ? primaryDark : primaryLight }
    static func bgTop(for s: ColorScheme) -> Color { s == .dark ? bgTopDark : bgTopLight }
    static func bgBottom(for s: ColorScheme) -> Color { s == .dark ? bgBottomDark : bgBottomLight }
}
