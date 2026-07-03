import SwiftUI

enum AuroraFont {
    private static let displayFamily = "Space Grotesk"
    private static let monoFamily = "JetBrains Mono"

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(displayFamily, size: size).weight(weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(monoFamily, size: size).weight(weight)
    }
}
