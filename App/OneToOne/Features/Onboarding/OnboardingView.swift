import Core
import SwiftUI

/// Знакомство при первом запуске: пол → имя и дата рождения → партнёр. Пара создаётся и на сервере,
/// дальше можно пригласить партнёра. Если партнёр уже создал пару — вход по его коду.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(PairingFlow.self) private var pairing
    @State private var me = PersonDraft(sex: .female)
    @State private var partner = PersonDraft(sex: .male)
    @State private var meSexChosen = false
    @State private var partnerSexTouched = false
    @State private var path: [Step] = []

    private enum Step: Hashable { case me, partner, join }

    var body: some View {
        if pairing.restoringCoupleID != nil {
            // Новый телефон или переустановка: пара есть, ключа нет — просим его у партнёра.
            RestoreAccessView()
        } else if pairing.awaitsProfile {
            // Вошли по коду или восстановили доступ и получили ключ: осталось выбрать себя в паре.
            ChooseMeView()
        } else {
            steps
        }
    }

    private var steps: some View {
        NavigationStack(path: $path) {
            SexStepView(selected: meSexChosen ? me.sex : nil, onChoose: chooseMySex, onJoin: { path = [.join] })
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .me:
                        PersonFormView(title: "Как тебя зовут?", draft: $me, buttonTitle: "Дальше") { () throws(OnboardingError) in
                            _ = try me.validated(today: DayKey(.now))
                            path = [.me, .partner]
                        }
                    case .partner:
                        PersonFormView(
                            title: "Партнёр",
                            draft: $partner,
                            buttonTitle: "Создать пару",
                            onSexPicked: { partnerSexTouched = true },
                            note: LossWarning.couple
                        ) { () throws(OnboardingError) in
                            try model.createCouple(me: me, partner: partner)
                            Task { await pairing.coupleCreated() }
                        }
                    case .join:
                        JoinCoupleView()
                    }
                }
        }
        // Вошли по коду, но ключ не получили и закрыли приложение: продолжаем с того же места.
        .onAppear {
            if pairing.joiningCoupleID != nil { path = [.join] }
        }
    }

    private func chooseMySex(_ sex: Sex) {
        me.sex = sex
        meSexChosen = true
        if !partnerSexTouched {
            partner.sex = sex == .male ? .female : .male
        }
        path = [.me]
    }
}

#if DEBUG
#Preview {
    let model = AppModel(store: InMemoryStore())
    OnboardingView()
        .environment(model)
        .environment(PairingFlow.preview(model: model))
}
#endif
