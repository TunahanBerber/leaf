import SwiftUI
import UIKit

// Sayfa numarasını elle klavyeyle yazmak yerine kaydırarak seçmek için —
// büyük canlı bir sayı göstergesi + Slider, her sayfa değiştiğinde hafif bir
// haptic ile. BookDetailView'daki "Sayfa Güncelle" ve AddNoteView'daki sayfa
// numarası alanı bunu paylaşıyor.
struct PageProgressSlider: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var page: Int
    let totalPages: Int

    private var safeTotalPages: Int { max(totalPages, 1) }

    private var pageBinding: Binding<Double> {
        Binding(
            get: { Double(page) },
            set: { newValue in
                let rounded = Int(newValue.rounded())
                if rounded != page {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                page = rounded
            }
        )
    }

    var body: some View {
        VStack(spacing: LeafSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: LeafSpacing.xxs) {
                Text("\(page)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(LeafColors.accent(for: scheme))
                    .contentTransition(.numericText(value: Double(page)))
                    .animation(LeafMotion.fast, value: page)
                Text("/ \(totalPages) sayfa")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(LeafColors.textSecondary(for: scheme))
                    .padding(.bottom, 6)
            }

            Slider(value: pageBinding, in: 0...Double(safeTotalPages), step: 1)
                .tint(LeafColors.accent(for: scheme))

            HStack {
                Text("0")
                Spacer()
                Text("%\(Int((Double(page) / Double(safeTotalPages)) * 100))")
                    .fontWeight(.semibold)
                    .foregroundStyle(LeafColors.accent(for: scheme))
                Spacer()
                Text("\(totalPages)")
            }
            .font(.system(size: 12))
            .foregroundStyle(LeafColors.textTertiary(for: scheme))
        }
    }
}
