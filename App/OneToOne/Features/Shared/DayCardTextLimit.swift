import SwiftUI

extension View {
    /// Карточка дня (подсказка у него, «Сегодня» у неё) растёт со шрифтом только до `.accessibility2`:
    /// крупнее «Фолликулярная,» и «Комплимент» не влезают в ширину карточки на iPhone SE и рвутся
    /// посреди слова. Предел на всю карточку, чтобы заголовок не стал крупнее текста под ним.
    func dayCardTextLimit() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
