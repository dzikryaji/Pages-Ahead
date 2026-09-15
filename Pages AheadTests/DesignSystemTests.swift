import Testing
import UIKit

@Suite("Design system")
struct DesignSystemTests {
    @Test("Bundled brand fonts are registered")
    func bundledBrandFontsAreRegistered() {
        #expect(UIFont(name: "BebasNeue-Regular", size: 24) != nil)
        #expect(UIFont(name: "Nunito-Regular", size: 17) != nil)
        #expect(UIFont(name: "Nunito-SemiBold", size: 17) != nil)
        #expect(UIFont(name: "Nunito-Bold", size: 17) != nil)
    }
}
