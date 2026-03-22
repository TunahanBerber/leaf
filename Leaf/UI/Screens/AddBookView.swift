import SwiftUI
import PhotosUI

// kitap ekleme ekranı — sheet olarak açılıyor
// fotoğraf seçici ile kapak, form ile bilgi girişi

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = ""
    @State private var photo: PhotosPickerItem?
    @State private var coverData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()
                ScrollView {
                    VStack(spacing: LeafSpacing.lg) {
                        coverPicker.padding(.top, LeafSpacing.md)

                        VStack(spacing: LeafSpacing.md) {
                            LeafTextField(title: "Kitap Adı", text: $title, placeholder: "Kitabın adını yazın")
                            LeafTextField(title: "Yazar", text: $author, placeholder: "Yazarın adını yazın")
                            LeafTextField(title: "Toplam Sayfa", text: $totalPages, placeholder: "Sayfa sayısını girin", keyboard: .numberPad)
                        }
                        .padding(.horizontal, LeafSpacing.md)
                    }
                    .padding(.bottom, LeafSpacing.xxxl)
                }
            }
            .navigationTitle("Kitap Ekle")
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
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $photo, matching: .images) {
            if let data = coverData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous))
            } else {
                VStack(spacing: LeafSpacing.sm) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(LeafColors.accent(for: scheme).opacity(0.6))
                    Text("Kapak Ekle")
                        .font(.system(size: 13))
                        .foregroundStyle(LeafColors.textTertiary(for: scheme))
                }
                .frame(width: 140, height: 200)
                .background {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .fill(LeafColors.surfacePrimary(for: scheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .strokeBorder(LeafColors.borderPrimary(for: scheme), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                }
            }
        }
        .onChange(of: photo) { _, val in
            Task {
                if let data = try? await val?.loadTransferable(type: Data.self) {
                    coverData = data
                }
            }
        }
    }

    private func save() {
        let book = Book(title: title, author: author, coverImageData: coverData, totalPages: Int(totalPages) ?? 0)
        ctx.insert(book)
        dismiss()
    }
}
