// SearchQualityTests.swift
// Kitap aramasının kalitesini ölçmek için gerçek sorgularla uçtan uca test —
// gerçek Google Books/OpenLibrary/Supabase çağrılarını kullanır (mock yok),
// çünkü asıl amaç skorlama parametrelerini kör tahminle değil, ölçerek ayarlamak.
//
// Çalıştırma: Xcode'da Cmd+U, ya da terminalden:
//   xcodebuild test -project Leaf.xcodeproj -scheme Leaf \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:LeafTests/SearchQualityTests
//
// Test sonunda konsola her sorgu için ilk 3 sonuç ve OK/FAIL raporu basılır —
// eşik/skorlama değiştirdikçe buraya bakıp gerçek etkisini gör.

import XCTest
@testable import Leaf

final class SearchQualityTests: XCTestCase {

    private struct Case {
        let query: String
        let expectTitleContains: String   // boşsa başlık kontrolü atlanır (sadece yazar aranıyorsa)
        let expectAuthorContains: String? // nil ise yazar kontrolü atlanır
    }

    // 20 gerçek sorgu: yaygın kitaplar, Türkçe yazarlar, typo'lu aramalar,
    // çok genel başlıklar, ve mevcut kelime-sırası zaafını gösteren bir örnek
    private let cases: [Case] = [
        Case(query: "1984", expectTitleContains: "1984", expectAuthorContains: "orwell"),
        Case(query: "sefiller", expectTitleContains: "sefiller", expectAuthorContains: "hugo"),
        Case(query: "harry potter taşı", expectTitleContains: "taşı", expectAuthorContains: "rowling"),
        Case(query: "harry poter", expectTitleContains: "harry potter", expectAuthorContains: "rowling"),
        Case(query: "orhan pamuk", expectTitleContains: "", expectAuthorContains: "pamuk"),
        Case(query: "nazım hikmet", expectTitleContains: "", expectAuthorContains: "hikmet"),
        Case(query: "atomik alışlanlıklar", expectTitleContains: "atomik", expectAuthorContains: "clear"),
        Case(query: "dune", expectTitleContains: "dune", expectAuthorContains: "herbert"),
        Case(query: "kürk mantolu madonna", expectTitleContains: "madonna", expectAuthorContains: "ali"),
        Case(query: "kürk mantolu madona", expectTitleContains: "madonna", expectAuthorContains: "ali"), // typo: eksik n
        Case(query: "yazar:tolstoy", expectTitleContains: "", expectAuthorContains: "tolstoy"),
        Case(query: "gece yarısı kütüphanesi", expectTitleContains: "kütüphanesi", expectAuthorContains: "haig"),
        Case(query: "fahrenheit 451", expectTitleContains: "451", expectAuthorContains: "bradbury"),
        Case(query: "yüzüklerin efendisi", expectTitleContains: "yüzüklerin", expectAuthorContains: "tolkien"),
        Case(query: "suç ve ceza", expectTitleContains: "suç", expectAuthorContains: "dostoyevski"),
        Case(query: "pride and prejudice", expectTitleContains: "pride", expectAuthorContains: "austen"),
        Case(query: "james clear", expectTitleContains: "", expectAuthorContains: "clear"),
        Case(query: "it stephen king", expectTitleContains: "it", expectAuthorContains: "king"),
        // kelime sırası karışık — mevcut substring/prefix skorlaması için bilinen zayıf nokta,
        // word-tokenized eşleşme eklenene kadar muhtemelen FAIL verecek
        Case(query: "taşı harry potter felsefe", expectTitleContains: "taşı", expectAuthorContains: "rowling"),
        Case(query: "kürek mantoli madona", expectTitleContains: "madonna", expectAuthorContains: "ali"), // ağır typo
        Case(query: "gorbi hikayesi", expectTitleContains: "", expectAuthorContains: nil), // muhtemelen çok az/sıfır sonuç — no-result davranışını da gözlemlemek için
        Case(query: "hakan günday", expectTitleContains: "", expectAuthorContains: "günday")
    ]

    @MainActor
    func testSearchQualityTop3() async {
        var passCount = 0
        var report: [String] = []

        for c in cases {
            let service = OpenLibraryService()
            await service.searchNow(query: c.query)
            let top3 = Array(service.results.prefix(3))

            let titleHit = c.expectTitleContains.isEmpty || top3.contains {
                normalize($0.title).contains(normalize(c.expectTitleContains))
            }
            let authorHit = c.expectAuthorContains == nil || top3.contains {
                normalize($0.authorsText).contains(normalize(c.expectAuthorContains!))
            }
            let pass = titleHit && authorHit
            if pass { passCount += 1 }

            let top3Desc = top3.isEmpty
                ? "(sonuç yok)"
                : top3.map { "\($0.title) — \($0.authorsText)" }.joined(separator: " | ")
            report.append("[\(pass ? "OK  " : "FAIL")] \"\(c.query)\" → \(top3Desc)")

            XCTAssertTrue(
                pass,
                "\"\(c.query)\" için beklenen ilk 3'te yok. Beklenen başlık: \"\(c.expectTitleContains)\", yazar: \"\(c.expectAuthorContains ?? "-")\". Gelenler: \(top3Desc)"
            )
        }

        let summary = """


        ================= ARAMA KALİTE RAPORU: \(passCount)/\(cases.count) geçti =================
        \(report.joined(separator: "\n"))
        ==============================================================================

        """
        print(summary)
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    }
}
