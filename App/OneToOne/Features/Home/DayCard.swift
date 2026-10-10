import Core
import SwiftUI

/// Карточка дня на главной: ему подсказка, ей фаза цикла и подбадривающая фраза.
struct DayCard: View {
    let forecast: CycleForecast
    let herMood: HerMood?
    let isWoman: Bool

    var body: some View {
        if isWoman {
            HerDayCard(forecast: forecast)
        } else {
            TipCard(tip: TipProvider.tip(forecast: forecast, herMood: herMood))
        }
    }
}

/// «Сегодня: Овуляция, 14-й день» и фраза под фазу.
private struct HerDayCard: View {
    let forecast: CycleForecast

    var body: some View {
        LabeledCard(title: "Сегодня") {
            if let dayOfCycle = forecast.dayOfCycle, forecast.phase != .unknown {
                Text("\(capitalized(forecast.phase.title)), \(dayOfCycle)-й день")
                    .font(.title3.weight(.semibold))
                if let cheer = CheerProvider.cheer(forecast: forecast) {
                    Text(cheer)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Отметь первый день месячных во вкладке «Цикл»")
                    .font(.title3.weight(.semibold))
            }
        }
    }

    /// «овуляция» → «Овуляция».
    private func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

#Preview {
    let ovulation = CycleForecast(phase: .ovulation, dayOfCycle: 14, averageLength: 28, nextPeriodStart: nil)
    let unknown = CycleForecast(phase: .unknown, dayOfCycle: nil, averageLength: 28, nextPeriodStart: nil)
    VStack {
        DayCard(forecast: ovulation, herMood: nil, isWoman: true)
        DayCard(forecast: unknown, herMood: nil, isWoman: true)
        DayCard(forecast: ovulation, herMood: nil, isWoman: false)
    }
    .padding()
}
