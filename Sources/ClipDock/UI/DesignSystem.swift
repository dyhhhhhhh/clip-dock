import SwiftUI

enum Design {
    static let primary = Color(red: 0.369, green: 0.416, blue: 0.824)
    static let canvas = Color(red: 0.004, green: 0.004, blue: 0.008)
    static let surface1 = Color(red: 0.059, green: 0.063, blue: 0.067)
    static let surface2 = Color(red: 0.078, green: 0.082, blue: 0.086)
    static let surface3 = Color(red: 0.094, green: 0.098, blue: 0.102)
    static let hairline = Color(red: 0.137, green: 0.145, blue: 0.165)
    static let hairlineStrong = Color(red: 0.204, green: 0.204, blue: 0.227)
    static let ink = Color(red: 0.969, green: 0.973, blue: 0.973)
    static let muted = Color(red: 0.541, green: 0.561, blue: 0.596)
    static let danger = Color(red: 0.92, green: 0.24, blue: 0.22)
}

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Design.canvas)
            .foregroundStyle(Design.ink)
    }
}

extension View {
    func clipDockPanel() -> some View {
        modifier(PanelBackground())
    }
}
