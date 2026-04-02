import SwiftUI

// not ekleme ekranı — sheet olarak açılıyor
// SwiftData yok; not direkt BookStore üzerinden Supabase'e kaydedilir

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: BookStore

    // Kitabı ID üzerinden takip ediyoruz; struct olduğu için reference yok
    let bookId: String

    @State private var title = ""
    @State private var content = ""
    @State private var pageNum = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()
                ScrollView {
                    VStack(spacing: LeafSpacing.md) {
                        LeafTextField(title: "Not Başlığı",     text: $title,   placeholder: "Notunuza bir başlık verin")
                        LeafTextField(title: "Sayfa Numarası",  text: $pageNum, placeholder: "İsteğe bağlı", keyboard: .numberPad)

                        // İçerik alanı
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
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        // Direkt Supabase'e yaz; store hem DB'ye kaydeder hem books[idx].notes'a ekler
        await store.addNote(
            title: title,
            content: content,
            pageNumber: Int(pageNum),
            to: bookId
        )
        dismiss()
    }
}
