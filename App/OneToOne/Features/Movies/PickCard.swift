import Core
import DesignSystem
import SwiftUI

/// Карточка вечера наверху вкладки «Фильмы»: начать подбор или присоединиться к нему.
struct PickCard: View {
    let state: PickCardState
    let onOpen: () -> Void
    let onNewPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.subheadline).opacity(0.9)
            Button(action: onOpen) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(BrandColor.pink.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            if state != .noPick {
                Button("Новый подбор", action: onNewPick)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(BrandGradient.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var title: String {
        switch state {
        case .noPick: "Что смотрим сегодня?"
        case .partnerStarted(_, let mood): "«\(mood.title)»"
        case .inProgress(let session, _): "«\(session.mood.title)»"
        }
    }

    private var subtitle: String {
        switch state {
        case .noPick: "Выберите настроение и свайпайте каждый на своём телефоне"
        case .partnerStarted(let name, _): "\(name) уже свайпает. Ваша очередь"
        case .inProgress(_, let count): count > 0 ? "Совпали: \(count)" : "Пока без совпадений"
        }
    }

    private var buttonTitle: String {
        switch state {
        case .noPick: "Выбрать фильм"
        case .partnerStarted: "Свайпать"
        case .inProgress: "Свайпать дальше"
        }
    }
}

#Preview {
    VStack {
        PickCard(state: .noPick, onOpen: {}, onNewPick: {})
        PickCard(state: .partnerStarted(partnerName: "Аня", mood: .light), onOpen: {}, onNewPick: {})
    }
    .padding()
}
