import AppKit

@MainActor enum BrandAssets {
    static func image(_ name: String) -> NSImage? {
        // Installed bundles use Contents/Resources; SwiftPM runs use its resource bundle.
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        return url.flatMap { NSImage(contentsOf: $0) }
    }
    static func statusImage() -> NSImage? {
        let image = image("StatusIcon")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        return image
    }
}
