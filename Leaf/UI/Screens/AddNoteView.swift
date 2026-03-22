import SwiftUI

// not ekleme ekranı — sheet olarak açılıyor

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme

    let book: Book
    @State private var title = ""
    @State private var content = ""
    @State private var pageNum = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()
                ScrollView {
                    VStack(spacing: LeafSpacing.md) {
                        LeafTextField(title: "Not Başlığı", text: $title, placeholder: "Notunuza bir başlık verin")
                        LeafTextField(title: "Sayfa Numarası", text: $pageNum, placeholder: "İsteğe bağlı", keyboard: .numberPad)

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
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
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
                    Button("Kaydet") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(LeafColors.accent(for: scheme))
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }

    private func save() {
        let note = BookNote(title: title, content: content, pageNumber: Int(pageNum), book: book)
        ctx.insert(note)
        dismiss()
    }
}
