import Foundation

// Şehir seçimi ve CHECK constraint'i profiles.city ile aynı 81 il listesi —
// biri değişirse diğeri de güncellenmeli.
//
// Liste burada zaten doğru Türkçe alfabetik sırada elle hazırlandı — çalışma
// zamanında `.sorted(using: .localizedStandard)` KULLANMIYORUZ, çünkü bu cihazın
// o anki sistem diline bağlı çalışır: telefon dili Türkçe değilse sıralama bozulur
// ve "İzmir" gibi noktalı/noktasız I içeren aramalar (localizedCaseInsensitiveContains)
// yanlış sonuç verebilir. Arama tarafında da aynı sebeple tr_TR locale'i sabitleniyor
// (bkz. CityPickerSheet).
enum TurkishProvinces {
    static let all: [String] = [
        "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Aksaray", "Amasya", "Ankara", "Antalya",
        "Ardahan", "Artvin", "Aydın", "Balıkesir", "Bartın", "Batman", "Bayburt", "Bilecik",
        "Bingöl", "Bitlis", "Bolu", "Burdur", "Bursa", "Çanakkale", "Çankırı", "Çorum",
        "Denizli", "Diyarbakır", "Düzce", "Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir",
        "Gaziantep", "Giresun", "Gümüşhane", "Hakkâri", "Hatay", "Iğdır", "Isparta", "İstanbul",
        "İzmir", "Kahramanmaraş", "Karabük", "Karaman", "Kars", "Kastamonu", "Kayseri",
        "Kırıkkale", "Kırklareli", "Kırşehir", "Kilis", "Kocaeli", "Konya", "Kütahya", "Malatya",
        "Manisa", "Mardin", "Mersin", "Muğla", "Muş", "Nevşehir", "Niğde", "Ordu", "Osmaniye",
        "Rize", "Sakarya", "Samsun", "Siirt", "Sinop", "Sivas", "Şanlıurfa", "Şırnak",
        "Tekirdağ", "Tokat", "Trabzon", "Tunceli", "Uşak", "Van", "Yalova", "Yozgat", "Zonguldak",
    ]
}
