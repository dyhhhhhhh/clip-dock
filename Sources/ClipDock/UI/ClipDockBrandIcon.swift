import AppKit
import SwiftUI

struct ClipDockBrandIcon: View {
    let size: CGFloat
    let tint: Color?

    init(size: CGFloat, tint: Color? = Design.primary) {
        self.size = size
        self.tint = tint
    }

    var body: some View {
        icon
            .frame(width: size, height: size)
            .accessibilityLabel("ClipDock")
    }

    @ViewBuilder private var icon: some View {
        if let image = ClipDockBrandIconAsset.image {
            let templateImage = Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()

            if let tint {
                templateImage.foregroundStyle(tint)
            } else {
                templateImage
            }
        } else {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: size * 0.76, weight: .semibold))
                .foregroundStyle(tint ?? Design.ink)
                .frame(width: size, height: size)
        }
    }
}

private enum ClipDockBrandIconAsset {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 64, height: 64)
        return image
    }()
}
