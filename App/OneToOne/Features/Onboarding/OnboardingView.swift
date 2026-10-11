import Core
import SwiftUI

/// Знакомство при первом запуске: пол → имя и дата рождения → партнёр.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var me = PersonDraft(sex: .female)
    @State private var partner = PersonDraft(sex: .male)
    @State private var meSexChosen = false
    @State private var partnerSexTouched = false
    @State private var path: [Step] = []

    private enum Step: Hashable { case me, partner }

    var body: some View {
        NavigationStack(path: $path) {
            SexStepView(selected: meSexChosen ? me.sex : nil, onChoose: chooseMySex)
                #if DEBUG
                // Второй симулятор берёт пару с сервера, а не создаёт свою (до #85).
                .toolbar {
                    NavigationLink("Синхр.") { DebugSyncView() }
                }
                #endif
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
                            onSexPicked: { partnerSexTouched = true }
                        ) { () throws(OnboardingError) in
                            try model.createCouple(me: me, partner: partner)
                        }
                    }
                }
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

#Preview {
    OnboardingView()
        .environment(AppModel(store: InMemoryStore()))
}
