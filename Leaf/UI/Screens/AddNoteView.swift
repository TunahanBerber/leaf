import SwiftUI

// not ekleme ekranı — sheet olarak açılıyor
// direkt BookStore üzerinden Supabase'e gönderiyorum, SwiftData yok

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: BookStore
    @Environment(SocialService.self) private var socialService

    // kitabı ID ile takip ediyorum — struct olduğu için reference tutmak mümkün değil
    let bookId: String

    @State private var title = ""
    @State private var content = ""
    @State private var hasPageNumber = false
    @State private var pageNum = 1
    @State private var shareAfterSave = false
    @State private var showSharePicker = false
    @State private var isSaving = false

    // Sayfa aralığını sınırlamak için kitabın toplam sayfa sayısını okuyorum —
    // yoksa slider'ın üst sınırını belirleyecek bir referans olmazdı.
    private var book: Book? {
        store.books.first { $0.id == bookId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()
                ScrollView {
                    VStack(spacing: LeafSpacing.md) {
                        LeafTextField(title: "Not Başlığı", text: $title, placeholder: "Notunuza bir başlık verin")

                        // Sayfa numarasını elle yazmak yerine kaydırarak seçiyoruz —
                        // toplam sayfa sayısı bilinmiyorsa (0) bu seçeneği hiç göstermiyoruz,
                        // aksi halde slider'ın anlamlı bir üst sınırı olmazdı.
                        if let book, book.totalPages > 0 {
                            VStack(alignment: .leading, spacing: LeafSpacing.sm) {
                                Toggle("Sayfa numarası ekle", isOn: $hasPageNumber.animation(LeafMotion.regular))
                                    .tint(LeafColors.accent(for: scheme))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(LeafColors.textSecondary(for: scheme))

                                if hasPageNumber {
                                    PageProgressSlider(page: $pageNum, totalPages: book.totalPages)
                                        .padding(LeafSpacing.md)
                                        .background {
                                            RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                                                .fill(LeafColors.surfacePrimary(for: scheme))
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                                                .strokeBorder(LeafColors.borderSubtle(for: scheme), lineWidth: 0.5)
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }

                        // içerik alanı
                        VStack(alignment: .leading, spacing: LeafSpacing.xs) {
                            Text("Not İçeriği")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LeafColors.textSecondary(for: scheme))

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $content)
                                    .font(.system(size: 15))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 200)

                                if content.isEmpty {
                                    Text("Notunuzu buraya yazın...")
                                        .font(.system(size: 15))
                                        .foregroundStyle(LeafColors.textTertiary(for: scheme))
                                        .padding(.top, 8).padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .padding(LeafSpacing.sm)
                            .background {
                                RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                                    .fill(LeafColors.surfacePrimary(for: scheme))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                                    .strokeBorder(LeafColors.borderSubtle(for: scheme), lineWidth: 0.5)
                            }
                        }

                        // Mesajlaşma zaten 18 yaş altına kapalı.
                        if socialService.isSocialAllowed {
                            Toggle("Kaydettikten sonra bir sohbete gönder", isOn: $shareAfterSave.animation(LeafMotion.regular))
                                .tint(LeafColors.accent(for: scheme))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LeafColors.textSecondary(for: scheme))
                        }
                    }
                    .padding(.horizontal, LeafSpacing.md)
                    .padding(.top, LeafSpacing.md)
                    .padding(.bottom, LeafSpacing.xxxl)
                }
            }
            .navigationTitle("Not Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(LeafColors.textSecondary(for: scheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(LeafColors.accent(for: scheme))
                        } else {
                            Text("Kaydet").fontWeight(.semibold)
                                .foregroundStyle(LeafColors.accent(for: scheme))
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
            // "Kaydettikten sonra gönder" açıksa bu sheet'i biz değil,
            // ShareBookToChatSheet kapanınca (onDismiss) kapatıyoruz —
            // yoksa notu kaydedip hemen ekrandan atlar, gönderme fırsatı kalmazdı.
            .sheet(isPresented: $showSharePicker, onDismiss: { dismiss() }) {
                if let book {
                    ShareBookToChatSheet(
                        book: book,
                        noteTitle: title,
                        noteContent: content,
                        notePageNumber: hasPageNumber ? pageNum : nil
                    )
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        // store hem Supabase'e kaydediyor hem de books[idx].notes'a ekliyor — tek satır iş
        await store.addNote(
            title: title,
            content: content,
            pageNumber: hasPageNumber ? pageNum : nil,
            to: bookId
        )
        if shareAfterSave {
            showSharePicker = true
        } else {
            dismiss()
        }
    }
}
