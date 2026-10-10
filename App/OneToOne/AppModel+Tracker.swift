import Core
import Foundation

/// Сколько оргазмов подставить в новую запись.
struct OrgasmDefaults: Equatable {
    let man: Int
    let woman: Int
}

/// Действия трекера: отметить, поправить, удалить секс.
extension AppModel {
    func logSex(types: Set<SexType>, orgasmsMan: Int, orgasmsWoman: Int, date: Date) {
        // Пока пары нет (онбординг не пройден), автор записи неизвестен: ставим одноразовый id.
        let entry = SexEntry(date: date, types: types, orgasmsMan: orgasmsMan,
                             orgasmsWoman: orgasmsWoman, createdBy: data.meID ?? UUID())
        update { $0.sexEntries.append(entry) }
    }

    func updateSex(_ entry: SexEntry) {
        update { data in
            guard let index = data.sexEntries.firstIndex(where: { $0.id == entry.id }) else { return }
            data.sexEntries[index] = entry
        }
    }

    func deleteSex(id: UUID) {
        update { $0.sexEntries.removeAll { $0.id == id } }
    }

    /// Как в самой поздней по дате записи, а в самой первой — по 1.
    var orgasmDefaults: OrgasmDefaults {
        guard let latest = data.sexEntries.max(by: { $0.date < $1.date }) else {
            return OrgasmDefaults(man: 1, woman: 1)
        }
        return OrgasmDefaults(man: latest.orgasmsMan, woman: latest.orgasmsWoman)
    }
}
