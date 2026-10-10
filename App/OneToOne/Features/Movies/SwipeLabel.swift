import Core
import DesignSystem
import SwiftUI

/// Метка «ДА» / «НЕТ» / «НА БУДУЩЕЕ», которая проступает на карточке, пока её тянут.
struct SwipeLabel: View {
    let action: SwipeAction

    var body: some View {
        Text(title)
            .font(.title.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(rotation))
    }

    private var title: String {
        switch action {
        case .yes: "ДА"
        case .no: "НЕТ"
        case .later: "НА БУДУЩЕЕ"
        }
    }

    private var color: Color {
        switch action {
        case .yes: BrandColor.pink.color
        case .no: .gray
        case .later: BrandColor.purple.color
        }
    }

    private var rotation: Double {
        switch action {
        case .yes: -12
        case .no: 12
        case .later: 0
        }
    }
}
