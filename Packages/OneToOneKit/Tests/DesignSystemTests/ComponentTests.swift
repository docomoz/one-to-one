import SwiftUI
import Testing
@testable import DesignSystem

@MainActor @Test func statTileKeepsTitleAndValue() {
    let tile = StatTile(title: "Оргазмы", value: "М 14 · Д 11")
    #expect(tile.title == "Оргазмы")
    #expect(tile.value == "М 14 · Д 11")
}

@MainActor @Test func gradientButtonRunsActionOnTap() {
    var tapped = false
    let button = GradientButton(title: "Выбрать фильм") { tapped = true }
    #expect(button.title == "Выбрать фильм")
    button.action()
    #expect(tapped)
}
