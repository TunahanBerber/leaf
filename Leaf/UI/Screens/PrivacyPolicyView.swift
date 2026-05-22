import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Group {
                            policySection(
                                title: "Gizlilik Politikası",
                                body: """
                                    Son güncelleme: Mayıs 2026

                                    Leaf uygulamasını kullandığınızda bazı kişisel verileriniz işlenmektedir. \
                                    Bu politika, hangi verilerin toplandığını, neden toplandığını ve nasıl \
                                    kullanıldığını açıklamaktadır.
                                    """
                            )

                            policySection(
                                title: "Toplanan Veriler",
                                body: """
                                    • E-posta adresi (hesap oluşturma ve kimlik doğrulama)
                                    • Kullanıcı adı, yaş ve biyografi (profil)
                                    • Kullanıcılar arası mesajlar (sohbet özelliği)
                                    • Kitap listesi ve notlar (kütüphane)
                                    • Cihaz bildirim tokeni (push bildirimler)
                                    """
                            )

                            policySection(
                                title: "Verilerin Kullanım Amacı",
                                body: """
                                    Toplanan veriler yalnızca aşağıdaki amaçlarla kullanılmaktadır:
                                    • Uygulama özelliklerinin sağlanması (mesajlaşma, keşif)
                                    • Hesap güvenliğinin korunması
                                    • Push bildirimlerin iletilmesi
                                    Verileriniz üçüncü taraflarla pazarlama amacıyla paylaşılmamaktadır.
                                    """
                            )

                            policySection(
                                title: "Verilerin Saklanması",
                                body: """
                                    Verileriniz Supabase altyapısında güvenli biçimde saklanmaktadır. \
                                    Supabase'in gizlilik politikasına supabase.com/privacy adresinden ulaşabilirsiniz.
                                    """
                            )

                            policySection(
                                title: "Haklarınız",
                                body: """
                                    • Verilerinize erişim talep edebilirsiniz.
                                    • Verilerinizin düzeltilmesini isteyebilirsiniz.
                                    • Hesabınızı ve tüm verilerinizi Ayarlar ekranından silebilirsiniz.
                                    • Kişisel veri işleme faaliyetlerine itiraz edebilirsiniz.
                                    """
                            )

                            policySection(
                                title: "İletişim",
                                body: """
                                    Gizlilik ile ilgili sorularınız için:
                                    tunahanberber123@gmail.com
                                    """
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Gizlilik Politikası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
            }
        }
    }

    private func policySection(title: String, body: String) -> some View {
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
