// ContentFilter.swift
// Mesaj gönderiminde basit bir küfür/taciz kelime filtresi — App Store moderasyon
// gereksinimi için client-side ilk savunma hattı. Sunucu tarafında değil burada
// tutuyorum çünkü amaç sadece bariz durumları göndermeden önce yakalamak.

import Foundation

enum ContentFilter {

    // Kelime listesi elle tutulmuyor — ooguz/turkce-kufur-karaliste GitHub
    // deposundaki karaliste.txt'nin bir kopyası (Leaf/Resources/karaliste.txt,
    // CC-BY-SA-4.0). Liste güncellenince buradaki dosyayı da tekrar indirip
    // değiştirmek yeterli, kod tarafında değişiklik gerekmiyor.
    // https://github.com/ooguz/turkce-kufur-karaliste/blob/master/karaliste.txt
    private static let bannedWords: Set<String> = {
        guard
            let url = Bundle.main.url(forResource: "karaliste", withExtension: "txt"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        let locale = Locale(identifier: "tr_TR")
        return Set(
            contents
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased(with: locale) }
                .filter { !$0.isEmpty }
        )
    }()

    // mesajda yasak kelime var mı diye bakar
    static func isAllowed(_ text: String) -> Bool {
        let normalized = text.lowercased(with: Locale(identifier: "tr_TR"))
        return !bannedWords.contains { normalized.contains($0) }
    }
}
