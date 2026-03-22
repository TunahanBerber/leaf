import SwiftUI

// web'deki 8pt spacing sistemi, köşe yuvarlaklıkları ve blur değerleri

enum LeafSpacing {
    static let xxs: CGFloat = 4     // --space-1
    static let xs: CGFloat = 8      // --space-2
    static let sm: CGFloat = 12     // --space-3
    static let md: CGFloat = 16     // --space-4
    static let lg: CGFloat = 20     // --space-5
    static let xl: CGFloat = 24     // --space-6
    static let xxl: CGFloat = 32    // --space-7
    static let xxxl: CGFloat = 40   // --space-8
}

enum LeafRadius {
    static let small: CGFloat = 10   // --radius-small
    static let medium: CGFloat = 14  // --radius-medium
    static let large: CGFloat = 18   // --radius-large
    static let xlarge: CGFloat = 24  // --radius-xlarge
}

// animasyon sabitleri — web'deki motion.css karşılığı
enum LeafMotion {
    static let fast: Animation = .easeOut(duration: 0.12)
    static let regular: Animation = .easeOut(duration: 0.18)
    static let slow: Animation = .easeOut(duration: 0.26)
    static let spring: Animation = .spring(response: 0.4, dampingFraction: 0.85)
    static let fadeIn: Animation = .easeOut(duration: 0.8)
    static let pressScale: CGFloat = 0.96
}
