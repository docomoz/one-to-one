import Core
import DesignSystem
import SwiftUI

/// Шаг 2 подбора: колода карточек. Вправо ♥, влево ✕, вверх — «на будущее».
struct SwipeDeckView: View {
    let session: PickSession
    @Environment(AppModel.self) private var model
    @Environment(\.movieCatalog) private var catalog
    @State private var deck: [Movie]?
    @State private var index = 0
    @State private var offset: CGSize = .zero
    @State private var isAnimating = false
    @State private var swipeCount = 0
    @State private var matchCount = 0

    /// Насколько надо утянуть карточку, чтобы она улетела.
    private let threshold: CGFloat = 120

    var body: some View {
        content
            .background(Palette.background)
            .navigationTitle(session.mood.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Колоду грузим один раз на открытие: это до 6 запросов к Кинопоиску из 200 в день.
                if deck == nil { deck = await model.deck(for: session, catalog: catalog) }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: swipeCount)
            .sensoryFeedback(.success, trigger: matchCount)
    }

    @ViewBuilder
    private var content: some View {
        if let deck {
            if index < deck.count {
                VStack(spacing: 20) {
                    Text("\(index + 1) из \(deck.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    cards(deck)
                    buttons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            } else {
                Text("Колода кончилась")
            }
        } else {
            ProgressView("Собираем колоду…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cards(_ deck: [Movie]) -> some View {
        ZStack {
            // Следующая карточка выглядывает из-под верхней.
            if index + 1 < deck.count {
                MovieCardView(movie: deck[index + 1])
                    .scaleEffect(0.95)
                    .id(deck[index + 1].id)
            }
            MovieCardView(movie: deck[index])
                .overlay(alignment: .top) { dragLabel }
                .offset(offset)
                .rotationEffect(.degrees(offset.width / 20))
                .gesture(drag)
                .id(deck[index].id)
                .accessibilityAction(named: "Да") { perform(.yes) }
                .accessibilityAction(named: "Нет") { perform(.no) }
                .accessibilityAction(named: "На будущее") { perform(.later) }
        }
    }

    @ViewBuilder
    private var dragLabel: some View {
        if let action = action(for: offset, threshold: 1) {
            SwipeLabel(action: action)
                .opacity(min(1, max(abs(offset.width), abs(offset.height)) / threshold))
                .padding(.top, 40)
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isAnimating { offset = value.translation }
            }
            .onEnded { value in
                guard !isAnimating else { return }
                if let action = action(for: value.translation, threshold: threshold) {
                    perform(action)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                }
            }
    }

    private var buttons: some View {
        HStack(spacing: 28) {
            RoundButton(systemImage: "xmark", label: "Нет", size: 64) { perform(.no) }
            RoundButton(systemImage: "bookmark.fill", label: "На будущее", size: 52) { perform(.later) }
            RoundButton(systemImage: "heart.fill", label: "Да", size: 64, isAccent: true) { perform(.yes) }
        }
    }

    /// Куда утянули карточку: вверх сильнее, чем вбок — «на будущее».
    private func action(for translation: CGSize, threshold: CGFloat) -> SwipeAction? {
        if translation.height < -threshold, abs(translation.height) > abs(translation.width) { return .later }
        if translation.width > threshold { return .yes }
        if translation.width < -threshold { return .no }
        return nil
    }

    private func perform(_ action: SwipeAction) {
        // Пока карточка улетает, новые нажатия не считаем: иначе один фильм свайпнется дважды.
        guard !isAnimating, let deck, index < deck.count else { return }
        isAnimating = true
        let movie = deck[index]
        let matched = model.swipe(action, movie: movie, in: session)
        swipeCount += 1

        let target: CGSize = switch action {
        case .yes: CGSize(width: 700, height: offset.height)
        case .no: CGSize(width: -700, height: offset.height)
        case .later: CGSize(width: offset.width, height: -1000)
        }
        withAnimation(.easeIn(duration: 0.25)) {
            offset = target
        } completion: {
            var noAnimation = Transaction()
            noAnimation.disablesAnimations = true
            withTransaction(noAnimation) {
                index += 1
                offset = .zero
            }
            isAnimating = false
            if matched { matchCount += 1 }
        }
    }
}

/// Круглая кнопка под колодой.
private struct RoundButton: View {
    let systemImage: String
    let label: String
    let size: CGFloat
    var isAccent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(isAccent ? AnyShapeStyle(.white) : AnyShapeStyle(BrandGradient.primary))
                .frame(width: size, height: size)
                .background {
                    if isAccent {
                        Circle().fill(BrandGradient.primary)
                    } else {
                        Circle().fill(Palette.tile)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    NavigationStack {
        SwipeDeckView(session: PickSession(mood: .light, startedBy: UUID(), startedAt: .now))
    }
    .environment(AppModel(store: InMemoryStore()))
    .environment(\.movieCatalog, PreviewCatalog())
}
