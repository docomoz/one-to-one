import SwiftUI

/// Плашка на сиреневом фоне со скруглёнными углами. Внутрь кладём что угодно.
public struct Card<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Palette.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    Card { Text("Любое содержимое") }
        .padding()
}
