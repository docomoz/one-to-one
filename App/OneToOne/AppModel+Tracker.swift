import Core
import Foundation

/// Сколько оргазмов подставить в новую запись.
struct OrgasmDefaults: Equatable {
    let man: Int
    let woman: Int
}

/// Действия трекера: отметить, поправить, удалить секс.
extension AppModel {
    /// Добавляет ещё одну запись. Если в этот день уже была, будет две: каждая — отдельный раз.
    func logSex(types: Set<SexType>, orgasmsMan: Int, orgasmsWoman: Int,
                condom: Bool? = nil, finish: SexFinish? = nil, day: DayKey) {
        // Пока пары нет (онбординг не пройден), автор записи неизвестен: ставим одноразовый id.
        let entry = SexEntry(day: day, types: types, orgasmsMan: orgasmsMan, orgasmsWoman: orgasmsWoman,
                             condom: condom, finish: finish, createdBy: data.meID ?? UUID())
        update { $0.sexEntries.append(Self.droppingProtectionIfNeeded(entry)) }
    }

    func updateSex(_ entry: SexEntry) {
        update { data in
            guard let index = data.sexEntries.firstIndex(where: { $0.id == entry.id }) else { return }
            data.sexEntries[index] = Self.droppingProtectionIfNeeded(entry)
        }
    }

    /// Про защиту спрашиваем только при «Классике». Сняли её — ответы стираем, иначе останется
    /// незаметная запись «без презерватива», и подсказка про таблетку сработает зря.
    private static func droppingProtectionIfNeeded(_ entry: SexEntry) -> SexEntry {
        guard !entry.types.contains(.vaginal) else { return entry }
        var entry = entry
        entry.condom = nil
        entry.finish = nil
        return entry
    }

    func deleteSex(id: UUID) {
        update { $0.sexEntries.removeAll { $0.id == id } }
    }

    /// Как в самой поздней по дню записи (из нескольких за день — в последней добавленной), а в самой первой — по 1.
    var orgasmDefaults: OrgasmDefaults {
        // `max` при равенстве отдаёт первый элемент, поэтому ищем в обратном порядке добавления.
        guard let latest = data.sexEntries.reversed().max(by: { $0.day < $1.day }) else {
            return OrgasmDefaults(man: 1, woman: 1)
        }
        return OrgasmDefaults(man: latest.orgasmsMan, woman: latest.orgasmsWoman)
    }
}

/// Действия календаря цикла: отметки дня, которые ставит она.
extension AppModel {
    func togglePeriodDay(_ day: DayKey) {
        update { $0.togglePeriodDay(day) }
    }

    func setHerMood(_ mood: HerMood?, for day: DayKey) {
        update { $0.setHerMood(mood, for: day) }
    }

    func toggleSymptom(_ symptom: Symptom, on day: DayKey) {
        update { $0.toggleSymptom(symptom, on: day) }
    }

    func addCustomSymptom(_ text: String, on day: DayKey) {
        update { $0.addCustomSymptom(text, on: day) }
    }
}
