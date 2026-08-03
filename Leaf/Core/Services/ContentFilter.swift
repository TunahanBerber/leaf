// ContentFilter.swift
// Mesaj gönderiminde basit bir küfür/taciz kelime filtresi — App Store moderasyon
// gereksinimi için client-side ilk savunma hattı. Sunucu tarafında değil burada
// tutuyorum çünkü amaç sadece bariz durumları göndermeden önce yakalamak.

import Foundation

enum ContentFilter {

    // basit bir liste — ihtiyaç oldukça buraya kelime eklemek yeterli
    private static let bannedWords: [String] = [
        "amk", "aq", "a.q", "orospu", "piç", "yavşak", "siktir",
        "ibne", "kahpe", "şerefsiz", "puşt", "gavat", "sürtük"
    ]

    // mesajda yasak kelime var mı diye bakar
    static func isAllowed(_ text: String) -> Bool {
        let normalized = text.lowercased(with: Locale(identifier: "tr_TR"))
        return !bannedWords.contains { normalized.contains($0) }
    }
}
