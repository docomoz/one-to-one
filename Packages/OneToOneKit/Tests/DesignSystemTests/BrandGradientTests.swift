import Testing
@testable import DesignSystem

@Test func primaryGradientGoesOrangePinkPurple() {
    #expect(BrandGradient.primaryStops == [.orange, .pink, .purple])
}

@Test func textGradientUsesFullInstagramRange() {
    #expect(BrandGradient.textStops == [.yellow, .orange, .pink, .purple, .blue])
}
