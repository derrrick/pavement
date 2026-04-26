import Foundation
import CoreText
import SwiftUI

/// One-shot registration of bundled custom fonts so SwiftUI's
/// `Font.custom(...)` can resolve them by family name without us
/// having to maintain `UIAppFonts` / `ATSApplicationFontsPath` entries
/// in the host app's Info.plist.
///
/// Inter — Christian Robertson / rsms, SIL Open Font License.
/// https://rsms.me/inter/
public enum AppFonts {
    public static let interFamilyName = "Inter"

    private static var didRegister = false

    /// Registers all fonts shipped in the PavementUI bundle. Idempotent —
    /// safe to call from multiple init sites (App / scene / preview).
    /// Prefer calling once during app launch.
    public static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true
        register(name: "InterVariable", ext: "ttf")
    }

    private static func register(name: String, ext: String) {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return
        }
        var error: Unmanaged<CFError>?
        // .process scope so our font is visible to the entire process,
        // including SwiftUI's internal font resolver.
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let cfErr = error?.takeRetainedValue()
            // CTFontManager returns "duplicate" on second register; harmless.
            if let cfErr, CFErrorGetCode(cfErr) != 105 {
                NSLog("[Pavement] Failed to register \(name).\(ext): \(cfErr)")
            }
        }
    }
}

public extension Font {
    /// Bundled Inter face — falls through to the system font if the
    /// register call hasn't happened yet.
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(AppFonts.interFamilyName, size: size).weight(weight)
    }
}
