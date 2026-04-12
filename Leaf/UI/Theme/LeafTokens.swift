import SwiftUI

// tasarım token'ları — spacing, köşe yuvarlaklığı ve animasyon sabitleri burada

enum LeafSpacing {
    static let xxs: CGFloat = 4     // çok küçük boşluk
    static let xs: CGFloat = 8      // küçük
    static let sm: CGFloat = 12     // biraz küçük
    static let md: CGFloat = 16     // standart
    static let lg: CGFloat = 20     // orta büyük
    static let xl: CGFloat = 24     // büyük
    static let xxl: CGFloat = 32    // daha büyük
    static let xxxl: CGFloat = 40   // en büyük
}

enum LeafRadius {
    static let small: CGFloat = 10   // küçük köşe
    static let medium: CGFloat = 14  // orta köşe
    static let large: CGFloat = 18   // büyük köşe
    static let xlarge: CGFloat = 24  // çok büyük köşe
}

// animasyon sabitleri — hız ve yay değerlerini tek yerde tutuyorum
enum LeafMotion {
    static let fast: Animation = .easeOut(duration: 0.12)
    static let regular: Animation = .easeOut(duration: 0.18)
    static let slow: Animation = .easeOut(duration: 0.26)
    static let spring: Animation = .spring(response: 0.4, dampingFraction: 0.85)
    static let fadeIn: Animation = .easeOut(duration: 0.8)
    static let pressScale: CGFloat = 0.96
}
