import SwiftUI

// Onboarding ve Ayarlar'daki şehir seçiminin ortak sheet'i. Arama tr_TR locale'ine
// sabitlenmiş case+diacritic-insensitive karşılaştırma kullanıyor — cihazın sistem
// dili Türkçe olmasa bile "izmir" yazınca "İzmir" bulunsun, "corum" yazınca "Çorum"
// bulunsun diye (bkz. TurkishProvinces.swift'teki not).
struct CityPickerSheet: View {
    @Binding var selectedCity: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""

    private static let turkishLocale = Locale(identifier: "tr_TR")

    private var filteredCities: [String] {
        guard !query.isEmpty else { return TurkishProvinces.all }
        return TurkishProvinces.all.filter {
            $0.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Self.turkishLocale
            ) != nil
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCities, id: \.self) { city in
                Button {
                    selectedCity = city
                    dismiss()
                } label: {
                    HStack {
                        Text(city).foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                        Spacer()
                        if city == selectedCity {
                            Image(systemName: "checkmark")
                                .foregroundStyle(LeafColors.accent(for: colorScheme))
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Şehir ara")
            .navigationTitle("Şehir Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
