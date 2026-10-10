import Foundation

/// Ответ на «Как вам фильм?». `skip` — закрыли вопрос без оценки, на колоду не влияет.
public enum MovieVerdict: String, Codable, Sendable {
    case like, dislike, skip
}

/// Оценка просмотренного фильма одним человеком.
public struct MovieRating: Codable, Equatable, Sendable {
    public let movieID: Int
    public let personID: UUID
    public let verdict: MovieVerdict
    public let date: Date

    public init(movieID: Int, personID: UUID, verdict: MovieVerdict, date: Date) {
        self.movieID = movieID
        self.personID = personID
        self.verdict = verdict
        self.date = date
    }
}
