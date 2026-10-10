import Testing
@testable import Core

@Test func moodGenresMatchKinopoisk() {
    #expect(Mood.laugh.genres == ["комедия"])
    #expect(Mood.light.genres == ["комедия", "семейный", "мультфильм"])
    #expect(Mood.thrill.genres == ["триллер", "ужасы"])
    #expect(Mood.cry.genres == ["драма"])
    #expect(Mood.immerse.genres == ["фантастика", "детектив", "приключения"])
    #expect(Mood.romance.genres == ["мелодрама"])
}
