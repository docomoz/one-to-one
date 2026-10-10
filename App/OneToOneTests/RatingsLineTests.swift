import Core
import Testing
@testable import OneToOne

@Test func ratingsLineShowsBoth() {
    #expect(Ratings(imdb: 7.4, kinopoisk: 7.83).line == "IMDb 7.4 · Кинопоиск 7.8")
}

@Test func ratingsLineSkipsMissing() {
    #expect(Ratings(imdb: nil, kinopoisk: 8).line == "Кинопоиск 8.0")
}

@Test func ratingsLineNilWhenNone() {
    #expect(Ratings(imdb: nil, kinopoisk: nil).line == nil)
}
