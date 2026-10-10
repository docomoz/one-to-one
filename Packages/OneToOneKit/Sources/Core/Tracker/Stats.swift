/// Счётчики трекера для экрана статистики.
public struct Stats: Equatable, Sendable {
    public let total: Int
    public let thisMonth: Int
    public let orgasmsMan: Int
    public let orgasmsWoman: Int
    /// Сколько раз был каждый вид. Есть все виды, даже с нулём.
    public let typeCounts: [SexType: Int]
    /// Дней подряд до сегодня (или до вчера, если сегодня ещё не было).
    public let currentStreak: Int
    /// Самая длинная серия дней подряд за всё время.
    public let bestStreak: Int

    public init(total: Int, thisMonth: Int, orgasmsMan: Int, orgasmsWoman: Int,
                typeCounts: [SexType: Int], currentStreak: Int, bestStreak: Int) {
        self.total = total
        self.thisMonth = thisMonth
        self.orgasmsMan = orgasmsMan
        self.orgasmsWoman = orgasmsWoman
        self.typeCounts = typeCounts
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
}
