import Core

#if DEBUG
extension AppData {
    /// Пара с записями, циклом, днём рождения партнёра через 12 дней и годовщиной через 20 дней (3 года) — для превью главной.
    static func homePreview(meIsWoman: Bool) -> AppData {
        let today = DayKey(.now)
        let birthday = today.adding(days: 12)
        let man = Person(name: "Максюша", sex: .male, birthDate: DayKey(year: 1990, month: birthday.month, day: birthday.day))
        let woman = Person(name: "Даша", sex: .female, birthDate: DayKey(year: 1995, month: birthday.month, day: birthday.day))
        var data = AppData()
        data.couple = try? Couple.make(man, woman)
        let anniversary = today.adding(days: 20)
        data.togetherSince = DayKey(year: anniversary.year - 3, month: anniversary.month, day: anniversary.day)
        data.meID = meIsWoman ? woman.id : man.id
        data.sexEntries = (0..<3).map {
            SexEntry(day: today.adding(days: -$0), types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, createdBy: man.id)
        }
        data.periodDays = Set((0..<5).map { today.adding(days: -13 + $0) })
        return data
    }
}
#endif
