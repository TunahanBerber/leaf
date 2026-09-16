import SwiftUI

// Kullanım Koşulları — PrivacyPolicyView ile aynı native pattern: harici bir linke
// bağımlı olmadan, offline çalışan, App Store 1.2 (UGC) için gereken "objectionable
// content'e sıfır tolerans + hesap/içerik kaldırma yetkisi" ifadesini içeren metin.
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Group {
                            section(
                                title: "Kullanım Koşulları",
                                body: """
                                    Son güncelleme: Mayıs 2026

                                    SocialLeaf'i kullanarak aşağıdaki koşulları kabul etmiş olursun. \
                                    Bu koşullar, hem kitap takip özelliklerini hem de 18 yaş ve üzeri \
                                    kullanıcılara açık sosyal/eşleştirme özelliklerini kapsar.
                                    """
                            )

                            section(
                                title: "Hesap ve Yaş Şartı",
                                body: """
                                    • Hesap oluşturmak için doğru bilgi vermeyi kabul edersin.
                                    • Sosyal özellikler (Keşfet, Mesajlar) yalnızca 18 yaş ve üzeri \
                                    kullanıcılara açıktır; 18 yaşından küçüklerden eşleştirme amaçlı \
                                    veri toplanmaz ve bu özellikler gösterilmez.
                                    • Hesabının güvenliğinden ve hesabın üzerinden yapılan işlemlerden \
                                    sen sorumlusun.
                                    """
                            )

                            section(
                                title: "Kullanıcı Davranış Kuralları",
                                body: """
                                    SocialLeaf, aşağıdaki davranış ve içeriklere karşı sıfır tolerans \
                                    uygular:
                                    • Taciz, zorbalık, tehdit veya nefret söylemi
                                    • Cinsel içerikli, müstehcen veya rahatsız edici görsel/metin paylaşımı
                                    • Reşit olmayanları hedef alan herhangi bir davranış
                                    • Spam, dolandırıcılık veya yanıltıcı içerik
                                    • Başka bir kullanıcının kimliğine bürünmek

                                    Bu kurallara aykırı davranan hesapları ve/veya içerikleri önceden \
                                    bildirimde bulunmaksızın kaldırma, askıya alma veya kalıcı olarak \
                                    kapatma hakkımızı saklı tutarız.
                                    """
                            )

                            section(
                                title: "Kullanıcı İçeriği",
                                body: """
                                    Paylaştığın notlar, mesajlar ve profil bilgileri sana aittir. \
                                    Bunları yalnızca uygulama içinde sana gösterebilmek ve ilgili \
                                    kullanıcılarla paylaşabilmek için sınırlı bir kullanım hakkı bize \
                                    verirsin. Başkalarının telif hakkına veya kişilik haklarına aykırı \
                                    içerik paylaşmamayı kabul edersin.
                                    """
                            )

                            section(
                                title: "Şikayet, Engelleme ve Moderasyon",
                                body: """
                                    Uygunsuz bir kullanıcıyı veya mesajı profil/sohbet ekranlarından \
                                    şikayet edebilir, istediğin kullanıcıyı engelleyebilirsin. \
                                    Şikayetler tarafımızca incelenir; ihlal tespit edilirse ilgili \
                                    içerik kaldırılabilir ve/veya hesap kapatılabilir.
                                    """
                            )

                            section(
                                title: "Sorumluluğun Sınırlandırılması",
                                body: """
                                    SocialLeaf, kullanıcılar arasındaki etkileşimlerden veya diğer \
                                    kullanıcıların paylaştığı içeriklerden doğabilecek zararlardan \
                                    sorumlu tutulamaz. Uygulama "olduğu gibi" sunulmaktadır.
                                    """
                            )

                            section(
                                title: "Değişiklikler",
                                body: """
                                    Bu koşulları zaman zaman güncelleyebiliriz. Önemli değişikliklerde \
                                    uygulama içinden bilgilendirileceksin.
                                    """
                            )

                            section(
                                title: "İletişim",
                                body: """
                                    Sorularınız için:
                                    socialleaf.app@gmail.com
                                    """
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Kullanım Koşulları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text(body)
                .font(.subheadline)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
