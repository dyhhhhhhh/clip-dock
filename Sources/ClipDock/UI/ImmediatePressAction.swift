import SwiftUI

struct ImmediatePressActionModifier: ViewModifier {
    let action: () -> Void
    @State private var hasHandledCurrentPress = false

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !hasHandledCurrentPress else { return }
                    hasHandledCurrentPress = true
                    action()
                }
                .onEnded { _ in
                    hasHandledCurrentPress = false
                },
        )
    }
}

extension View {
    func onImmediatePress(_ action: @escaping () -> Void) -> some View {
        modifier(ImmediatePressActionModifier(action: action))
    }
}
