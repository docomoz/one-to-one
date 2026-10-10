import Testing
@testable import DesignSystem

@Test func brandColorsMatchMockupHex() {
    #expect(BrandColor.yellow.hex == 0xFEDA75)
    #expect(BrandColor.orange.hex == 0xFA7E1E)
    #expect(BrandColor.pink.hex == 0xD62976)
    #expect(BrandColor.purple.hex == 0x962FBF)
    #expect(BrandColor.blue.hex == 0x4F5BD5)
}

@Test func hexSplitsIntoRGBComponents() {
    let rgb = RGB(hex: 0xFA7E1E)
    #expect(rgb.red == 250.0 / 255)
    #expect(rgb.green == 126.0 / 255)
    #expect(rgb.blue == 30.0 / 255)
}

@Test func tileIsLilacInLightThemeAndPlumInDark() {
    #expect(Palette.tileHex(isDark: false) == 0xF4F0F7)
    #expect(Palette.tileHex(isDark: true) == 0x2A2231)
}
